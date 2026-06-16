using System.Security.Claims;
using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.WorkoutSets;

public static class WorkoutSetEndpoints
{
    public static IEndpointRouteBuilder MapWorkoutSetEndpoints(this IEndpointRouteBuilder routes)
    {
        var trainerGroup = routes.MapGroup("/workout-sets");

        trainerGroup.MapGet("/", ListTrainerSets).RequireAuthorization("TrainerOnly");
        trainerGroup.MapPost("/", Create).RequireAuthorization("TrainerOnly");
        trainerGroup.MapGet("/{setId:guid}", GetTrainerSet).RequireAuthorization("TrainerOnly");
        trainerGroup.MapPut("/{setId:guid}", Update).RequireAuthorization("TrainerOnly");
        trainerGroup.MapPost("/{setId:guid}/assignments", Assign).RequireAuthorization("TrainerOnly");
        trainerGroup.MapDelete("/{setId:guid}/assignments/{traineeUserId}", Unassign).RequireAuthorization("TrainerOnly");

        var traineeGroup = routes.MapGroup("/trainee/workout-sets");

        traineeGroup.MapGet("/", ListTraineeSets).RequireAuthorization("TraineeOnly");
        traineeGroup.MapGet("/{setId:guid}", GetTraineeSet).RequireAuthorization("TraineeOnly");

        return routes;
    }

    private static async Task<IResult> ListTrainerSets(
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var trainerUserId = UserId(principal);
        if (trainerUserId is null)
        {
            return Results.Unauthorized();
        }

        var workoutSets = await QueryTrainerSets(dbContext)
            .Where(set => set.TrainerUserId == trainerUserId)
            .ToListAsync(cancellationToken);

        return Results.Ok(workoutSets
            .OrderByDescending(set => set.UpdatedAt)
            .Select(WorkoutSetMapping.ToSummary)
            .ToArray());
    }

    private static async Task<IResult> Create(
        CreateWorkoutSetRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var trainerUserId = UserId(principal);
        if (trainerUserId is null)
        {
            return Results.Unauthorized();
        }

        var rows = ValidateAndMapRows(request.Rows, out var rowError);
        if (rowError is not null)
        {
            return Results.BadRequest(new { error = rowError });
        }

        var nameError = WorkoutSetValidation.ValidateSetName(request.Name);
        if (nameError is not null)
        {
            return Results.BadRequest(new { error = nameError });
        }

        var now = DateTimeOffset.UtcNow;
        var workoutSet = new WorkoutSet
        {
            Id = Guid.NewGuid(),
            TrainerUserId = trainerUserId,
            Name = request.Name.Trim(),
            CreatedAt = now,
            UpdatedAt = now,
        };

        foreach (var row in rows)
        {
            row.WorkoutSetId = workoutSet.Id;
            workoutSet.Rows.Add(row);
        }

        dbContext.WorkoutSets.Add(workoutSet);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Results.Created($"/workout-sets/{workoutSet.Id}", WorkoutSetMapping.ToDetail(workoutSet));
    }

    private static async Task<IResult> GetTrainerSet(
        Guid setId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var workoutSet = await FindTrainerSet(setId, principal, dbContext, cancellationToken);
        return workoutSet is null ? Results.NotFound() : Results.Ok(WorkoutSetMapping.ToDetail(workoutSet));
    }

    private static async Task<IResult> Update(
        Guid setId,
        UpdateWorkoutSetRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var workoutSet = await FindTrainerSet(setId, principal, dbContext, cancellationToken);
        if (workoutSet is null)
        {
            return Results.NotFound();
        }

        var nameError = WorkoutSetValidation.ValidateSetName(request.Name);
        if (nameError is not null)
        {
            return Results.BadRequest(new { error = nameError });
        }

        var rows = ValidateAndMapRows(request.Rows, out var rowError);
        if (rowError is not null)
        {
            return Results.BadRequest(new { error = rowError });
        }

        workoutSet.Name = request.Name.Trim();
        workoutSet.UpdatedAt = DateTimeOffset.UtcNow;
        dbContext.WorkoutSetRows.RemoveRange(workoutSet.Rows);
        foreach (var row in rows)
        {
            row.WorkoutSetId = workoutSet.Id;
            dbContext.WorkoutSetRows.Add(row);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        dbContext.ChangeTracker.Clear();

        var reloaded = await FindTrainerSet(setId, principal, dbContext, cancellationToken);
        return Results.Ok(WorkoutSetMapping.ToDetail(reloaded ?? workoutSet));
    }

    private static async Task<IResult> Assign(
        Guid setId,
        AssignWorkoutSetRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var trainerUserId = UserId(principal);
        if (trainerUserId is null)
        {
            return Results.Unauthorized();
        }

        var workoutSet = await FindTrainerSet(setId, principal, dbContext, cancellationToken);
        if (workoutSet is null)
        {
            return Results.NotFound();
        }

        var traineeUserIds = request.TraineeUserIds
            .Select(id => id.Trim())
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .ToArray();
        if (traineeUserIds.Length == 0)
        {
            return Results.BadRequest(new { error = "At least one trainee user ID is required." });
        }

        if (traineeUserIds.Distinct(StringComparer.Ordinal).Count() != traineeUserIds.Length)
        {
            return Results.BadRequest(new { error = "Trainee user IDs must be unique." });
        }

        var linkedTraineeIds = await dbContext.Users
            .Where(user =>
                traineeUserIds.Contains(user.Id) &&
                user.LiftMateRole == UserRole.Trainee &&
                user.TrainerUserId == trainerUserId)
            .Select(user => user.Id)
            .ToListAsync(cancellationToken);

        if (linkedTraineeIds.Count != traineeUserIds.Length)
        {
            return Results.BadRequest(new { error = "All assignment targets must be linked trainees." });
        }

        var existingIds = workoutSet.Assignments
            .Select(assignment => assignment.TraineeUserId)
            .ToHashSet(StringComparer.Ordinal);
        var now = DateTimeOffset.UtcNow;
        foreach (var traineeUserId in traineeUserIds.Where(id => !existingIds.Contains(id)))
        {
            dbContext.WorkoutSetAssignments.Add(new WorkoutSetAssignment
            {
                Id = Guid.NewGuid(),
                WorkoutSetId = workoutSet.Id,
                TraineeUserId = traineeUserId,
                AssignedByTrainerUserId = trainerUserId,
                AssignedAt = now,
            });
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        dbContext.ChangeTracker.Clear();

        var reloaded = await FindTrainerSet(setId, principal, dbContext, cancellationToken);
        return Results.Ok(WorkoutSetMapping.ToDetail(reloaded ?? workoutSet));
    }

    private static async Task<IResult> Unassign(
        Guid setId,
        string traineeUserId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var workoutSet = await FindTrainerSet(setId, principal, dbContext, cancellationToken);
        if (workoutSet is null)
        {
            return Results.NotFound();
        }

        var assignment = workoutSet.Assignments.SingleOrDefault(
            assignment => assignment.TraineeUserId == traineeUserId);
        if (assignment is not null)
        {
            dbContext.WorkoutSetAssignments.Remove(assignment);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return Results.NoContent();
    }

    private static async Task<IResult> ListTraineeSets(
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var traineeUserId = UserId(principal);
        if (traineeUserId is null)
        {
            return Results.Unauthorized();
        }

        var assignments = await QueryTraineeAssignments(dbContext, traineeUserId)
            .ToListAsync(cancellationToken);

        return Results.Ok(assignments
            .OrderByDescending(assignment => assignment.WorkoutSet?.UpdatedAt)
            .Select(WorkoutSetMapping.ToTraineeAssigned)
            .ToArray());
    }

    private static async Task<IResult> GetTraineeSet(
        Guid setId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var traineeUserId = UserId(principal);
        if (traineeUserId is null)
        {
            return Results.Unauthorized();
        }

        var assignment = await QueryTraineeAssignments(dbContext, traineeUserId)
            .SingleOrDefaultAsync(assignment => assignment.WorkoutSetId == setId, cancellationToken);

        return assignment is null
            ? Results.NotFound()
            : Results.Ok(WorkoutSetMapping.ToTraineeAssigned(assignment));
    }

    private static IQueryable<WorkoutSet> QueryTrainerSets(ApplicationDbContext dbContext)
    {
        return dbContext.WorkoutSets
            .Include(set => set.Rows)
            .Include(set => set.Assignments)
            .ThenInclude(assignment => assignment.TraineeUser);
    }

    private static Task<WorkoutSet?> FindTrainerSet(
        Guid setId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var trainerUserId = UserId(principal);
        if (trainerUserId is null)
        {
            return Task.FromResult<WorkoutSet?>(null);
        }

        return QueryTrainerSets(dbContext)
            .SingleOrDefaultAsync(set => set.Id == setId && set.TrainerUserId == trainerUserId, cancellationToken);
    }

    private static IQueryable<WorkoutSetAssignment> QueryTraineeAssignments(
        ApplicationDbContext dbContext,
        string traineeUserId)
    {
        return dbContext.WorkoutSetAssignments
            .Include(assignment => assignment.WorkoutSet)
            .ThenInclude(set => set!.TrainerUser)
            .Include(assignment => assignment.WorkoutSet)
            .ThenInclude(set => set!.Rows)
            .Where(assignment =>
                assignment.TraineeUserId == traineeUserId &&
                assignment.WorkoutSet != null &&
                assignment.WorkoutSet.TrainerUserId == assignment.TraineeUser!.TrainerUserId);
    }

    private static IReadOnlyList<WorkoutSetRow> ValidateAndMapRows(
        IReadOnlyList<WorkoutSetRowRequest> requests,
        out string? error)
    {
        if (requests.Count == 0)
        {
            error = "At least one workout set row is required.";
            return [];
        }

        var rows = new List<WorkoutSetRow>();
        var rowPositions = new HashSet<(int ExerciseOrder, int SetIndex)>();
        foreach (var request in requests)
        {
            var validationError = WorkoutSetValidation.ValidateRow(
                request.ExerciseOrder,
                request.SetIndex,
                request.ExerciseName,
                request.ExerciseType,
                request.Reps,
                request.Weight,
                request.Seconds);
            if (validationError is not null)
            {
                error = validationError;
                return [];
            }

            if (!rowPositions.Add((request.ExerciseOrder, request.SetIndex)))
            {
                error = "Workout set rows must not duplicate exercise order and set index.";
                return [];
            }

            rows.Add(new WorkoutSetRow
            {
                Id = Guid.NewGuid(),
                ExerciseOrder = request.ExerciseOrder,
                SetIndex = request.SetIndex,
                ExerciseName = request.ExerciseName.Trim(),
                ExerciseType = request.ExerciseType.Trim(),
                Reps = request.Reps,
                Weight = request.Weight,
                Seconds = request.Seconds,
            });
        }

        error = null;
        return rows;
    }

    private static string? UserId(ClaimsPrincipal principal)
    {
        return principal.FindFirstValue(ClaimTypes.NameIdentifier);
    }
}
