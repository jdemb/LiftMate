using System.Security.Claims;
using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.SharedSessions;

public static class SharedSessionEndpoints
{
    public static RouteGroupBuilder MapSharedSessionEndpoints(this IEndpointRouteBuilder routes)
    {
        var group = routes.MapGroup("/shared-sessions");

        group.MapPost("/", Create).RequireAuthorization("TrainerOnly");
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
        CancellationToken cancellationToken)
    {
        var trainerUserId = SharedSessionAccess.UserId(principal);
        if (trainerUserId is null)
        {
            return Results.Unauthorized();
        }

        var trainee = await userManager.Users.SingleOrDefaultAsync(
            user => user.Id == request.TraineeUserId,
            cancellationToken);
        if (trainee is null || trainee.LiftMateRole != UserRole.Trainee)
        {
            return Results.BadRequest(new { error = "Trainee user not found." });
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
            TraineeUserId = trainee.Id,
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

        return Results.Created($"/shared-sessions/{session.Id}", ToResponse(session));
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

        if (!SharedSessionAccess.IsParticipant(session, principal))
        {
            return Results.Forbid();
        }

        return Results.Ok(ToResponse(session));
    }

    private static async Task<IResult> UpdateValue(
        Guid sessionId,
        Guid valueId,
        UpdateSharedSessionValueRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var session = await FindSession(dbContext, sessionId, cancellationToken);
        if (session is null)
        {
            return Results.NotFound();
        }

        var userId = SharedSessionAccess.UserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        if (!SharedSessionAccess.IsParticipant(session, userId))
        {
            return Results.Forbid();
        }

        if (session.Status != SharedSessionStatus.Active)
        {
            return Results.Conflict(new { error = "Shared session is not active." });
        }

        var value = session.Values.SingleOrDefault(value => value.Id == valueId);
        if (value is null)
        {
            return Results.NotFound();
        }

        var validationError = ValidateValue(value.ExerciseType, request.Reps, request.Weight, request.Seconds);
        if (validationError is not null)
        {
            return Results.BadRequest(new { error = validationError });
        }

        var now = DateTimeOffset.UtcNow;
        value.Reps = request.Reps;
        value.Weight = request.Weight;
        value.Seconds = request.Seconds;
        value.UpdatedByUserId = userId;
        value.UpdatedAt = now;
        session.Version += 1;
        session.UpdatedAt = now;

        await dbContext.SaveChangesAsync(cancellationToken);

        return Results.Ok(ToResponse(session));
    }

    private static Task<IResult> Complete(
        Guid sessionId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        return Close(sessionId, SharedSessionStatus.Completed, SharedSessionStatus.Cancelled, principal, dbContext, cancellationToken);
    }

    private static Task<IResult> Cancel(
        Guid sessionId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        return Close(sessionId, SharedSessionStatus.Cancelled, SharedSessionStatus.Completed, principal, dbContext, cancellationToken);
    }

    private static async Task<IResult> Close(
        Guid sessionId,
        string targetStatus,
        string conflictStatus,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var session = await FindSession(dbContext, sessionId, cancellationToken);
        if (session is null)
        {
            return Results.NotFound();
        }

        if (!SharedSessionAccess.IsParticipant(session, principal))
        {
            return Results.Forbid();
        }

        if (session.Status == targetStatus)
        {
            return Results.Ok(ToResponse(session));
        }

        if (session.Status == conflictStatus)
        {
            return Results.Conflict(new { error = $"Shared session is already {conflictStatus}." });
        }

        var now = DateTimeOffset.UtcNow;
        session.Status = targetStatus;
        session.Version += 1;
        session.UpdatedAt = now;
        session.ClosedAt = now;

        await dbContext.SaveChangesAsync(cancellationToken);

        return Results.Ok(ToResponse(session));
    }

    private static Task<SharedSession?> FindSession(
        ApplicationDbContext dbContext,
        Guid sessionId,
        CancellationToken cancellationToken)
    {
        return dbContext.SharedSessions
            .Include(session => session.Values.OrderBy(value => value.SetIndex).ThenBy(value => value.Id))
            .SingleOrDefaultAsync(session => session.Id == sessionId, cancellationToken);
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

    private static SharedSessionResponse ToResponse(SharedSession session)
    {
        return new SharedSessionResponse(
            session.Id,
            session.TrainerUserId,
            session.TraineeUserId,
            session.Status,
            session.Version,
            session.CreatedAt,
            session.UpdatedAt,
            session.ClosedAt,
            session.Values
                .OrderBy(value => value.SetIndex)
                .ThenBy(value => value.Id)
                .Select(ToResponse)
                .ToArray());
    }

    private static SharedSessionValueResponse ToResponse(SharedSessionValue value)
    {
        return new SharedSessionValueResponse(
            value.Id,
            value.ExerciseName,
            value.ExerciseType,
            value.SetIndex,
            value.Reps,
            value.Weight,
            value.Seconds,
            value.UpdatedByUserId,
            value.UpdatedAt);
    }
}
