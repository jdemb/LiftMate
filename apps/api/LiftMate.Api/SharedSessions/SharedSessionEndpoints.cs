using System.Data;
using System.Security.Claims;
using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using LiftMate.Api.TrainerGuidance;
using LiftMate.Api.TrainingProgress;
using LiftMate.Api.WorkoutSets;
using LiftMate.Api.WeeklyStreaks;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.SharedSessions;

public static class SharedSessionEndpoints
{
    public static RouteGroupBuilder MapSharedSessionEndpoints(this IEndpointRouteBuilder routes)
    {
        var group = routes.MapGroup("/shared-sessions");

        group.MapPost("/", Create).RequireAuthorization("TrainerOnly");
        group.MapPost("/from-workout-set", StartFromWorkoutSet).RequireAuthorization();
        group.MapGet("/active", GetActive).RequireAuthorization();
        group.MapGet("/{sessionId:guid}", Get).RequireAuthorization();
        group.MapPatch("/{sessionId:guid}/values/{valueId:guid}", UpdateValue).RequireAuthorization();
        group.MapPost("/{sessionId:guid}/complete", Complete).RequireAuthorization();
        group.MapPost("/{sessionId:guid}/cancel", Cancel).RequireAuthorization();

        return group;
    }

    private static async Task<IResult> Create(
        CreateSharedSessionRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        UserManager<ApplicationUser> userManager,
        SharedSessionBroadcaster broadcaster,
        CancellationToken cancellationToken)
    {
        var trainerUserId = SharedSessionAccess.UserId(principal);
        if (trainerUserId is null)
        {
            return Results.Unauthorized();
        }

        var trainer = await userManager.Users.SingleOrDefaultAsync(
            user => user.Id == trainerUserId,
            cancellationToken);
        if (trainer is null)
        {
            return Results.Unauthorized();
        }

        var traineeEmail = request.TraineeEmail.Trim();
        if (string.IsNullOrWhiteSpace(traineeEmail))
        {
            return Results.BadRequest(new { error = "Trainee email is required." });
        }

        var normalizedTraineeEmail = userManager.NormalizeEmail(traineeEmail);
        var trainee = await userManager.Users.SingleOrDefaultAsync(
            user => user.NormalizedEmail == normalizedTraineeEmail,
            cancellationToken);
        if (trainee is null || trainee.LiftMateRole != UserRole.Trainee)
        {
            return Results.BadRequest(new { error = "Trainee user not found." });
        }

        if (!string.Equals(trainee.TrainerUserId, trainerUserId, StringComparison.Ordinal))
        {
            return Results.Forbid();
        }

        var hasActiveSession = await dbContext.SharedSessions.AnyAsync(
            session => session.TraineeUserId == trainee.Id && session.Status == SharedSessionStatus.Active,
            cancellationToken);
        if (hasActiveSession)
        {
            return Results.Conflict(new { error = "Trainee already has an active shared session." });
        }

        if (request.Values.Count == 0)
        {
            return Results.BadRequest(new { error = "At least one session value is required." });
        }

        var values = new List<SharedSessionValue>();
        foreach (var valueRequest in request.Values)
        {
            var validationError = ValidateValue(valueRequest.ExerciseType, valueRequest.Reps, valueRequest.Weight, valueRequest.Seconds);
            if (validationError is not null)
            {
                return Results.BadRequest(new { error = validationError });
            }

            var exerciseName = valueRequest.ExerciseName.Trim();
            if (string.IsNullOrWhiteSpace(exerciseName))
            {
                return Results.BadRequest(new { error = "Exercise name is required." });
            }

            values.Add(new SharedSessionValue
            {
                Id = Guid.NewGuid(),
                ExerciseName = exerciseName,
                ExerciseType = valueRequest.ExerciseType.Trim(),
                ExerciseOrder = valueRequest.SetIndex,
                SetIndex = valueRequest.SetIndex,
                Reps = valueRequest.Reps,
                Weight = valueRequest.Weight,
                Seconds = valueRequest.Seconds,
            });
        }

        var now = DateTimeOffset.UtcNow;
        var session = new SharedSession
        {
            Id = Guid.NewGuid(),
            TrainerUserId = trainerUserId,
            TrainerUser = trainer,
            TraineeUserId = trainee.Id,
            TraineeUser = trainee,
            StartedByUserId = trainerUserId,
            StartedByUser = trainer,
            StartedByRole = UserRole.Trainer,
            WorkoutSetName = "Trening",
            RestSeconds = 90,
            Status = SharedSessionStatus.Active,
            Version = 1,
            CreatedAt = now,
            UpdatedAt = now,
        };

        foreach (var value in values)
        {
            session.Values.Add(value);
        }

        dbContext.SharedSessions.Add(session);
        await dbContext.SaveChangesAsync(cancellationToken);
        await broadcaster.BroadcastStartedAsync(session, cancellationToken);
        await broadcaster.BroadcastUpdatedAsync(session, cancellationToken);

        return Results.Created($"/shared-sessions/{session.Id}", SharedSessionMapping.ToResponse(session));
    }

    private static async Task<IResult> StartFromWorkoutSet(
        StartSharedSessionFromWorkoutSetRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        UserManager<ApplicationUser> userManager,
        SharedSessionBroadcaster broadcaster,
        CancellationToken cancellationToken)
    {
        var currentUserId = SharedSessionAccess.UserId(principal);
        if (currentUserId is null)
        {
            return Results.Unauthorized();
        }

        var isTrainer = principal.HasClaim(ClaimTypes.Role, UserRole.Trainer);
        var isTrainee = principal.HasClaim(ClaimTypes.Role, UserRole.Trainee);
        if (!isTrainer && !isTrainee)
        {
            return Results.Forbid();
        }

        IResult? terminalResult = null;
        SharedSession? startedSession = null;
        var executionStrategy = dbContext.Database.CreateExecutionStrategy();

        await executionStrategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);
            dbContext.ChangeTracker.Clear();

            var workoutSet = await dbContext.WorkoutSets
                .Include(set => set.Rows)
                .Include(set => set.Assignments)
                .SingleOrDefaultAsync(
                    set => set.Id == request.WorkoutSetId && set.DeletedAt == null,
                    cancellationToken);
            if (workoutSet is null)
            {
                terminalResult = Results.NotFound();
                return;
            }

            ApplicationUser? trainer;
            ApplicationUser? trainee;
            string startedByRole;

            if (isTrainer)
            {
                if (!string.Equals(workoutSet.TrainerUserId, currentUserId, StringComparison.Ordinal))
                {
                    terminalResult = Results.NotFound();
                    return;
                }

                if (string.IsNullOrWhiteSpace(request.TraineeUserId))
                {
                    terminalResult = Results.BadRequest(new { error = "Trainee user id is required for trainer starts." });
                    return;
                }

                trainee = await userManager.Users.SingleOrDefaultAsync(
                    user => user.Id == request.TraineeUserId,
                    cancellationToken);
                if (trainee is null || trainee.LiftMateRole != UserRole.Trainee)
                {
                    terminalResult = Results.BadRequest(new { error = "Trainee user not found." });
                    return;
                }

                if (!string.Equals(trainee.TrainerUserId, currentUserId, StringComparison.Ordinal))
                {
                    terminalResult = Results.Forbid();
                    return;
                }

                trainer = await userManager.Users.SingleOrDefaultAsync(
                    user => user.Id == currentUserId,
                    cancellationToken);
                startedByRole = UserRole.Trainer;
            }
            else
            {
                if (!string.IsNullOrWhiteSpace(request.TraineeUserId) &&
                    !string.Equals(request.TraineeUserId, currentUserId, StringComparison.Ordinal))
                {
                    terminalResult = Results.Forbid();
                    return;
                }

                trainee = await userManager.Users.SingleOrDefaultAsync(
                    user => user.Id == currentUserId,
                    cancellationToken);
                if (trainee is null || trainee.LiftMateRole != UserRole.Trainee || string.IsNullOrWhiteSpace(trainee.TrainerUserId))
                {
                    terminalResult = Results.Forbid();
                    return;
                }

                if (!string.Equals(workoutSet.TrainerUserId, trainee.TrainerUserId, StringComparison.Ordinal))
                {
                    terminalResult = Results.NotFound();
                    return;
                }

                trainer = await userManager.Users.SingleOrDefaultAsync(
                    user => user.Id == workoutSet.TrainerUserId,
                    cancellationToken);
                startedByRole = UserRole.Trainee;
            }

            if (trainer is null)
            {
                terminalResult = Results.Forbid();
                return;
            }

            var isAssigned = workoutSet.Assignments.Any(
                assignment => string.Equals(assignment.TraineeUserId, trainee.Id, StringComparison.Ordinal));
            if (!isAssigned)
            {
                terminalResult = Results.Forbid();
                return;
            }

            if (workoutSet.Rows.Count == 0)
            {
                terminalResult = Results.BadRequest(new { error = "Workout set must contain at least one row." });
                return;
            }

            var hasActiveSession = await dbContext.SharedSessions.AnyAsync(
                session => session.TraineeUserId == trainee.Id && session.Status == SharedSessionStatus.Active,
                cancellationToken);
            if (hasActiveSession)
            {
                terminalResult = Results.Conflict(new { error = "Trainee already has an active shared session." });
                return;
            }

            var now = DateTimeOffset.UtcNow;
            var projectedValues = await dbContext.WorkoutProgresses
                .Where(progress =>
                    progress.TraineeUserId == trainee.Id &&
                    progress.WorkoutSetId == workoutSet.Id)
                .SelectMany(progress => progress.Values)
                .ToDictionaryAsync(value => value.WorkoutSetRowId, cancellationToken);
            var session = new SharedSession
            {
                Id = Guid.NewGuid(),
                TrainerUserId = trainer.Id,
                TrainerUser = trainer,
                TraineeUserId = trainee.Id,
                TraineeUser = trainee,
                WorkoutSetId = workoutSet.Id,
                WorkoutSet = workoutSet,
                WorkoutSetName = workoutSet.Name,
                RestSeconds = workoutSet.RestSeconds,
                StartedByUserId = currentUserId,
                StartedByRole = startedByRole,
                Status = SharedSessionStatus.Active,
                Version = 1,
                CreatedAt = now,
                UpdatedAt = now,
            };

            foreach (var row in workoutSet.Rows.OrderBy(row => row.ExerciseOrder).ThenBy(row => row.SetIndex).ThenBy(row => row.Id))
            {
                projectedValues.TryGetValue(row.Id, out var projected);
                session.Values.Add(new SharedSessionValue
                {
                    Id = Guid.NewGuid(),
                    ExerciseId = row.ExerciseId,
                    WorkoutSetRowId = row.Id,
                    ExerciseOrder = row.ExerciseOrder,
                    ExerciseName = row.ExerciseName,
                    ExerciseType = row.ExerciseType,
                    SetIndex = row.SetIndex,
                    Reps = projected?.Reps ?? row.Reps,
                    Weight = projected?.Weight ?? row.Weight,
                    Seconds = projected?.Seconds ?? row.Seconds,
                    IsDone = false,
                    CompletedAt = null,
                });
            }

            dbContext.SharedSessions.Add(session);
            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            startedSession = session;
        });

        if (terminalResult is not null)
        {
            return terminalResult;
        }

        var started = startedSession ?? throw new InvalidOperationException("Shared session start did not complete.");
        await broadcaster.BroadcastStartedAsync(started, cancellationToken);
        await broadcaster.BroadcastUpdatedAsync(started, cancellationToken);

        return Results.Created($"/shared-sessions/{started.Id}", SharedSessionMapping.ToResponse(started));
    }

    private static async Task<IResult> GetActive(
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var userId = SharedSessionAccess.UserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var sessions = await dbContext.SharedSessions
            .Include(session => session.TrainerUser)
            .Include(session => session.TraineeUser)
            .Include(session => session.Values.OrderBy(value => value.ExerciseOrder).ThenBy(value => value.SetIndex).ThenBy(value => value.Id))
            .Where(session =>
                session.Status == SharedSessionStatus.Active &&
                (session.TrainerUserId == userId || session.TraineeUserId == userId))
            .ToListAsync(cancellationToken);

        var session = sessions
            .Where(session => SharedSessionAccess.CanAccess(session, principal, userId))
            .OrderByDescending(session => session.UpdatedAt)
            .FirstOrDefault();

        return session is null ? Results.NotFound() : Results.Ok(SharedSessionMapping.ToResponse(session));
    }

    private static async Task<IResult> Get(
        Guid sessionId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var session = await FindSession(dbContext, sessionId, cancellationToken);
        if (session is null)
        {
            return Results.NotFound();
        }

        if (!SharedSessionAccess.CanAccess(session, principal))
        {
            return Results.Forbid();
        }

        return Results.Ok(SharedSessionMapping.ToResponse(session));
    }

    private static async Task<IResult> UpdateValue(
        Guid sessionId,
        Guid valueId,
        UpdateSharedSessionValueRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        SharedSessionBroadcaster broadcaster,
        CancellationToken cancellationToken)
    {
        var userId = SharedSessionAccess.UserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        IResult? terminalResult = null;
        var executionStrategy = dbContext.Database.CreateExecutionStrategy();

        await executionStrategy.ExecuteAsync(async () =>
        {
            terminalResult = null;
            await using var transaction = await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);
            dbContext.ChangeTracker.Clear();

            var session = await FindSession(dbContext, sessionId, cancellationToken);
            if (session is null)
            {
                terminalResult = Results.NotFound();
                return;
            }

            if (!CanUpdateValues(session, principal, userId))
            {
                terminalResult = Results.Forbid();
                return;
            }

            if (session.Status != SharedSessionStatus.Active)
            {
                terminalResult = Results.Conflict(new { error = "Shared session is not active." });
                return;
            }

            var value = session.Values.SingleOrDefault(value => value.Id == valueId);
            if (value is null)
            {
                terminalResult = Results.NotFound();
                return;
            }

            var validationError = ValidateUpdatedValue(value, request, out var reps, out var weight, out var seconds);
            if (validationError is not null)
            {
                terminalResult = Results.BadRequest(new { error = validationError });
                return;
            }

            var now = DateTimeOffset.UtcNow;
            value.Reps = reps;
            value.Weight = weight;
            value.Seconds = seconds;
            if (request.IsDone.HasValue)
            {
                value.IsDone = request.IsDone.Value;
                value.CompletedAt = value.IsDone ? value.CompletedAt ?? now : null;
            }
            value.UpdatedByUserId = userId;
            value.UpdatedAt = now;
            session.Version += 1;
            session.UpdatedAt = now;

            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });

        if (terminalResult is not null)
        {
            return terminalResult;
        }

        dbContext.ChangeTracker.Clear();
        var updatedSession = await FindSession(dbContext, sessionId, cancellationToken);
        if (updatedSession is null)
        {
            return Results.Problem("Shared session update did not produce a result.");
        }

        await broadcaster.BroadcastUpdatedAsync(updatedSession, cancellationToken);
        return Results.Ok(SharedSessionMapping.ToResponse(updatedSession));
    }

    private static async Task<IResult> Complete(
        Guid sessionId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        WorkoutProgressProjector projector,
        TrainerGuidanceEvaluator guidanceEvaluator,
        WeeklyStreakService weeklyStreakService,
        SharedSessionBroadcaster broadcaster,
        CancellationToken cancellationToken)
    {
        IResult? terminalResult = null;
        SharedSession? completedSession = null;
        var executionStrategy = dbContext.Database.CreateExecutionStrategy();

        await executionStrategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);
            dbContext.ChangeTracker.Clear();

            var session = await FindSession(dbContext, sessionId, cancellationToken);
            if (session is null)
            {
                terminalResult = Results.NotFound();
                return;
            }

            if (!SharedSessionAccess.CanAccess(session, principal))
            {
                terminalResult = Results.Forbid();
                return;
            }

            if (session.Status == SharedSessionStatus.Completed)
            {
                terminalResult = Results.Ok(SharedSessionMapping.ToResponse(session));
                return;
            }

            if (session.Status == SharedSessionStatus.Cancelled)
            {
                terminalResult = Results.Conflict(new { error = "Shared session is already cancelled." });
                return;
            }

            var completedAt = DateTimeOffset.UtcNow;
            session.Status = SharedSessionStatus.Completed;
            session.Version += 1;
            session.UpdatedAt = completedAt;
            session.ClosedAt = completedAt;

            await dbContext.SaveChangesAsync(cancellationToken);
            await projector.ProjectAsync(session, completedAt, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
            await weeklyStreakService.RecalculateForTraineeAsync(
                session.TraineeUserId,
                cancellationToken);
            await guidanceEvaluator.EvaluateWeightStagnationAsync(session.TraineeUserId, cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            completedSession = session;
        });

        if (terminalResult is not null)
        {
            return terminalResult;
        }

        if (completedSession is null)
        {
            return Results.Problem("Shared session completion did not produce a result.");
        }

        dbContext.ChangeTracker.Clear();
        var canonicalSession = await FindSession(dbContext, sessionId, cancellationToken);
        if (canonicalSession is null)
        {
            return Results.Problem("Shared session completion did not produce a result.");
        }

        await broadcaster.BroadcastUpdatedAsync(canonicalSession, cancellationToken);
        return Results.Ok(SharedSessionMapping.ToResponse(canonicalSession));
    }

    private static Task<IResult> Cancel(
        Guid sessionId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        SharedSessionBroadcaster broadcaster,
        CancellationToken cancellationToken)
    {
        return Close(sessionId, SharedSessionStatus.Cancelled, SharedSessionStatus.Completed, principal, dbContext, broadcaster, cancellationToken);
    }

    private static async Task<IResult> Close(
        Guid sessionId,
        string targetStatus,
        string conflictStatus,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        SharedSessionBroadcaster broadcaster,
        CancellationToken cancellationToken)
    {
        IResult? terminalResult = null;
        var executionStrategy = dbContext.Database.CreateExecutionStrategy();

        await executionStrategy.ExecuteAsync(async () =>
        {
            terminalResult = null;
            await using var transaction = await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);
            dbContext.ChangeTracker.Clear();

            var session = await FindSession(dbContext, sessionId, cancellationToken);
            if (session is null)
            {
                terminalResult = Results.NotFound();
                return;
            }

            if (!SharedSessionAccess.CanAccess(session, principal))
            {
                terminalResult = Results.Forbid();
                return;
            }

            if (session.Status == targetStatus)
            {
                terminalResult = Results.Ok(SharedSessionMapping.ToResponse(session));
                return;
            }

            if (session.Status == conflictStatus)
            {
                terminalResult = Results.Conflict(new { error = $"Shared session is already {conflictStatus}." });
                return;
            }

            var now = DateTimeOffset.UtcNow;
            session.Status = targetStatus;
            session.Version += 1;
            session.UpdatedAt = now;
            session.ClosedAt = now;

            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });

        if (terminalResult is not null)
        {
            return terminalResult;
        }

        dbContext.ChangeTracker.Clear();
        var closedSession = await FindSession(dbContext, sessionId, cancellationToken);
        if (closedSession is null)
        {
            return Results.Problem("Shared session close did not produce a result.");
        }

        await broadcaster.BroadcastUpdatedAsync(closedSession, cancellationToken);
        return Results.Ok(SharedSessionMapping.ToResponse(closedSession));
    }

    private static Task<SharedSession?> FindSession(
        ApplicationDbContext dbContext,
        Guid sessionId,
        CancellationToken cancellationToken)
    {
        return dbContext.SharedSessions
            .Include(session => session.TrainerUser)
            .Include(session => session.TraineeUser)
            .Include(session => session.Values.OrderBy(value => value.ExerciseOrder).ThenBy(value => value.SetIndex).ThenBy(value => value.Id))
            .SingleOrDefaultAsync(session => session.Id == sessionId, cancellationToken);
    }

    private static bool CanUpdateValues(SharedSession session, ClaimsPrincipal principal, string userId)
    {
        if (!SharedSessionAccess.CanAccess(session, principal, userId))
        {
            return false;
        }

        if (string.Equals(session.TrainerUserId, userId, StringComparison.Ordinal))
        {
            return principal.HasClaim(ClaimTypes.Role, UserRole.Trainer);
        }

        return string.Equals(session.TraineeUserId, userId, StringComparison.Ordinal) &&
            string.Equals(session.StartedByRole, UserRole.Trainee, StringComparison.Ordinal) &&
            string.Equals(session.StartedByUserId, userId, StringComparison.Ordinal);
    }

    private static string? ValidateUpdatedValue(
        SharedSessionValue value,
        UpdateSharedSessionValueRequest request,
        out int? reps,
        out decimal? weight,
        out int? seconds)
    {
        reps = request.Reps ?? value.Reps;
        weight = request.Weight ?? value.Weight;
        seconds = request.Seconds ?? value.Seconds;

        return ValidateValue(value.ExerciseType, reps, weight, seconds);
    }

    private static string? ValidateValue(string exerciseType, int? reps, decimal? weight, int? seconds)
    {
        var type = exerciseType.Trim();
        return type switch
        {
            ExerciseValueType.RepsWeight when reps is null || weight is null => "Reps and weight are required for repsWeight values.",
            ExerciseValueType.RepsWeight when seconds is not null => "Seconds are not allowed for repsWeight values.",
            ExerciseValueType.RepsOnly when reps is null => "Reps are required for repsOnly values.",
            ExerciseValueType.RepsOnly when weight is not null || seconds is not null => "Weight and seconds are not allowed for repsOnly values.",
            ExerciseValueType.Time when seconds is null => "Seconds are required for time values.",
            ExerciseValueType.Time when reps is not null || weight is not null => "Reps and weight are not allowed for time values.",
            _ when !ExerciseValueType.IsValid(type) => "Invalid exercise type.",
            _ => null,
        };
    }

}
