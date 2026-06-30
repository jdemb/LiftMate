using System.Security.Claims;
using System.Security.Cryptography;
using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using LiftMate.Api.WorkoutSets;
using LiftMate.Api.WeeklyStreaks;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.Auth;

public static class PairingEndpoints
{
    private const string InviteCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private const int InviteCodeLength = 6;
    private const int MaxCodeGenerationAttempts = 8;

    public static IEndpointRouteBuilder MapPairingEndpoints(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/trainer/relationship", GetTrainerRelationship)
            .RequireAuthorization("TrainerOnly");

        routes.MapPost("/trainer/invite-code", GenerateTrainerInviteCode)
            .RequireAuthorization("TrainerOnly");

        routes.MapGet("/trainee/relationship", GetTraineeRelationship)
            .RequireAuthorization("TraineeOnly");

        routes.MapPost("/trainee/trainer-link", ClaimTrainerInviteCode)
            .RequireAuthorization("TraineeOnly");

        return routes;
    }

    private static async Task<IResult> GetTrainerRelationship(
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        WeeklyStreakService weeklyStreakService,
        CancellationToken cancellationToken)
    {
        var trainerUserId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (trainerUserId is null)
        {
            return Results.Unauthorized();
        }

        var inviteCode = await GetOrCreateInviteCode(trainerUserId, dbContext, cancellationToken);
        if (inviteCode is null)
        {
            return Results.Problem("Could not generate a unique invite code.");
        }

        var traineeUsers = await dbContext.Users
            .Where(user => user.TrainerUserId == trainerUserId && user.LiftMateRole == UserRole.Trainee)
            .OrderBy(user => user.DisplayName)
            .ThenBy(user => user.Email)
            .ToListAsync(cancellationToken);

        var traineeIds = traineeUsers.Select(user => user.Id).ToArray();
        var legacyTraineeIds = traineeUsers
            .Where(user => user.TrainerLinkedAt is null)
            .Select(user => user.Id)
            .ToArray();
        var legacyTokenRows = await dbContext.RefreshTokens
            .Where(token => legacyTraineeIds.Contains(token.UserId))
            .Select(token => new { token.UserId, token.CreatedAt })
            .ToListAsync(cancellationToken);
        var legacyConnectedAt = legacyTokenRows
            .GroupBy(token => token.UserId)
            .ToDictionary(
                group => group.Key,
                group => group.Min(token => token.CreatedAt));
        var weeklyStreaks = await weeklyStreakService.GetResponsesForTraineesAsync(
            traineeIds,
            cancellationToken);
        var activeSessions = await dbContext.SharedSessions
            .Where(session =>
                session.TrainerUserId == trainerUserId &&
                traineeIds.Contains(session.TraineeUserId) &&
                session.Status == SharedSessionStatus.Active)
            .Select(session => new
            {
                session.TraineeUserId,
                Summary = new ActiveSharedSessionSummaryResponse(
                    session.Id,
                    session.WorkoutSetId,
                    session.WorkoutSet == null ? null : session.WorkoutSet.Name,
                    session.StartedByUserId,
                    session.StartedByRole,
                    session.UpdatedAt),
            })
            .ToDictionaryAsync(session => session.TraineeUserId, session => session.Summary, cancellationToken);

        var assignedSetRows = await dbContext.WorkoutSetAssignments
            .Include(assignment => assignment.WorkoutSet)
            .ThenInclude(workoutSet => workoutSet!.Rows)
            .Where(assignment =>
                traineeIds.Contains(assignment.TraineeUserId) &&
                assignment.WorkoutSet != null &&
                assignment.WorkoutSet.DeletedAt == null &&
                assignment.WorkoutSet.TrainerUserId == trainerUserId)
            .ToListAsync(cancellationToken);
        var assignedSetsByTrainee = assignedSetRows
            .GroupBy(assignment => assignment.TraineeUserId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyList<AssignedWorkoutSetSummaryResponse>)group
                    .Select(assignment =>
                    {
                        var workoutSet = assignment.WorkoutSet!;
                        return new AssignedWorkoutSetSummaryResponse(
                            workoutSet.Id,
                            workoutSet.Name,
                            workoutSet.Rows.Select(row => row.ExerciseOrder).Distinct().Count(),
                            workoutSet.Rows.Count,
                            workoutSet.UpdatedAt);
                    })
                    .OrderBy(summary => summary.Name)
                    .ThenBy(summary => summary.Id)
                    .ToArray());

        var trainees = traineeUsers
            .Select(user => new TrainerTraineeResponse(
                user.Id,
                user.Email ?? string.Empty,
                user.DisplayName,
                user.TrainerLinkedAt ??
                    (legacyConnectedAt.TryGetValue(user.Id, out var registeredAt)
                        ? registeredAt
                        : null),
                activeSessions.GetValueOrDefault(user.Id),
                assignedSetsByTrainee.GetValueOrDefault(user.Id) ?? [],
                weeklyStreaks[user.Id]))
            .ToArray();

        return Results.Ok(new TrainerRelationshipSummaryResponse(inviteCode.Code, trainees));
    }

    private static async Task<IResult> GenerateTrainerInviteCode(
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var trainerUserId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (trainerUserId is null)
        {
            return Results.Unauthorized();
        }

        var inviteCode = await GetOrCreateInviteCode(trainerUserId, dbContext, cancellationToken);
        return inviteCode is null
            ? Results.Problem("Could not generate a unique invite code.")
            : Results.Ok(new TrainerInviteCodeResponse(inviteCode.Code));
    }

    private static async Task<IResult> GetTraineeRelationship(
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        WeeklyStreakService weeklyStreakService,
        CancellationToken cancellationToken)
    {
        var traineeUserId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (traineeUserId is null)
        {
            return Results.Unauthorized();
        }

        var trainee = await dbContext.Users
            .Include(user => user.TrainerUser)
            .SingleOrDefaultAsync(user => user.Id == traineeUserId, cancellationToken);
        if (trainee is null)
        {
            return Results.Unauthorized();
        }

        var trainer = trainee.TrainerUser is null
            ? null
            : new TraineeTrainerResponse(
                trainee.TrainerUser.Id,
                trainee.TrainerUser.Email ?? string.Empty,
                trainee.TrainerUser.DisplayName);

        var weeklyStreak = await weeklyStreakService.GetResponseForTraineeAsync(
            traineeUserId,
            cancellationToken);

        return Results.Ok(new TraineeRelationshipSummaryResponse(trainer, weeklyStreak));
    }

    private static async Task<TrainerInviteCode?> GetOrCreateInviteCode(
        string trainerUserId,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var existing = await dbContext.TrainerInviteCodes.SingleOrDefaultAsync(
            inviteCode => inviteCode.TrainerUserId == trainerUserId,
            cancellationToken);
        if (existing is not null)
        {
            return existing;
        }

        for (var attempt = 0; attempt < MaxCodeGenerationAttempts; attempt += 1)
        {
            var code = GenerateCode();
            var isTaken = await dbContext.TrainerInviteCodes.AnyAsync(
                inviteCode => inviteCode.Code == code,
                cancellationToken);
            if (isTaken)
            {
                continue;
            }

            var inviteCode = new TrainerInviteCode
            {
                Id = Guid.NewGuid(),
                Code = code,
                TrainerUserId = trainerUserId,
                CreatedAt = DateTimeOffset.UtcNow,
            };

            dbContext.TrainerInviteCodes.Add(inviteCode);
            await dbContext.SaveChangesAsync(cancellationToken);

            return inviteCode;
        }

        return null;
    }

    private static async Task<IResult> ClaimTrainerInviteCode(
        ClaimTrainerInviteCodeRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        UserManager<ApplicationUser> userManager,
        SharedSessionBroadcaster broadcaster,
        CancellationToken cancellationToken)
    {
        var traineeUserId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (traineeUserId is null)
        {
            return Results.Unauthorized();
        }

        var code = NormalizeCode(request.Code);
        if (code is null)
        {
            return Results.BadRequest(new { error = "Invite code is required." });
        }

        var trainee = await userManager.Users.SingleOrDefaultAsync(
            user => user.Id == traineeUserId,
            cancellationToken);
        if (trainee is null)
        {
            return Results.Unauthorized();
        }

        if (trainee.LiftMateRole != UserRole.Trainee)
        {
            return Results.Forbid();
        }

        var inviteCode = await dbContext.TrainerInviteCodes
            .Include(value => value.TrainerUser)
            .SingleOrDefaultAsync(value => value.Code == code, cancellationToken);
        if (inviteCode?.TrainerUser is null)
        {
            return Results.NotFound(new { error = "Trainer invite code was not found." });
        }

        if (inviteCode.TrainerUser.LiftMateRole != UserRole.Trainer)
        {
            return Results.BadRequest(new { error = "Invite code owner is not a trainer." });
        }

        if (inviteCode.TrainerUserId == trainee.Id)
        {
            return Results.BadRequest(new { error = "A trainee cannot link to themselves." });
        }

        var linkedAt = DateTimeOffset.UtcNow;
        var previousTrainerUserId = trainee.TrainerUserId;
        trainee.TrainerUserId = inviteCode.TrainerUserId;
        trainee.TrainerLinkedAt = linkedAt;
        inviteCode.LastUsedAt = linkedAt;
        List<SharedSession> cancelledSessions = [];
        List<WorkoutSetAssignment> staleAssignments = [];
        if (previousTrainerUserId is not null &&
            !string.Equals(previousTrainerUserId, inviteCode.TrainerUserId, StringComparison.Ordinal))
        {
            var now = DateTimeOffset.UtcNow;
            cancelledSessions = await dbContext.SharedSessions
                .Include(session => session.TrainerUser)
                .Include(session => session.TraineeUser)
                .Include(session => session.Values.OrderBy(value => value.ExerciseOrder).ThenBy(value => value.SetIndex).ThenBy(value => value.Id))
                .Where(session => session.TraineeUserId == trainee.Id && session.Status == SharedSessionStatus.Active)
                .ToListAsync(cancellationToken);

            foreach (var session in cancelledSessions)
            {
                session.Status = SharedSessionStatus.Cancelled;
                session.Version += 1;
                session.UpdatedAt = now;
                session.ClosedAt = now;
            }

            staleAssignments = await dbContext.WorkoutSetAssignments
                .Include(assignment => assignment.WorkoutSet)
                .Where(assignment =>
                    assignment.TraineeUserId == trainee.Id &&
                    assignment.WorkoutSet != null &&
                    assignment.WorkoutSet.TrainerUserId == previousTrainerUserId)
                .ToListAsync(cancellationToken);
            dbContext.WorkoutSetAssignments.RemoveRange(staleAssignments);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        foreach (var session in cancelledSessions)
        {
            await broadcaster.BroadcastUpdatedAsync(session, cancellationToken);
        }

        return Results.Ok(TokenService.ToUserResponse(trainee));
    }

    private static string GenerateCode()
    {
        Span<char> code = stackalloc char[InviteCodeLength];
        Span<byte> random = stackalloc byte[InviteCodeLength];
        RandomNumberGenerator.Fill(random);

        for (var i = 0; i < code.Length; i += 1)
        {
            code[i] = InviteCodeAlphabet[random[i] % InviteCodeAlphabet.Length];
        }

        return new string(code);
    }

    private static string? NormalizeCode(string code)
    {
        var normalized = code.Trim().ToUpperInvariant();
        if (normalized.Length != InviteCodeLength)
        {
            return null;
        }

        return normalized.All(InviteCodeAlphabet.Contains) ? normalized : null;
    }
}
