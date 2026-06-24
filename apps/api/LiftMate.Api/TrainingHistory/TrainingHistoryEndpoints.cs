using System.Security.Claims;
using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.TrainingHistory;

public static class TrainingHistoryEndpoints
{
    private const int PageSize = 20;

    public static IEndpointRouteBuilder MapTrainingHistoryEndpoints(this IEndpointRouteBuilder routes)
    {
        var group = routes.MapGroup("/training-history").RequireAuthorization();
        group.MapGet("/sessions", ListSessions);
        group.MapGet("/sessions/{sessionId:guid}", GetSession);
        group.MapGet("/exercises/{exerciseId:guid}", GetExerciseProgress);
        return routes;
    }

    private static async Task<IResult> ListSessions(
        string? traineeUserId,
        string? cursor,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var targetResult = await ResolveTargetAsync(
            principal,
            traineeUserId,
            dbContext,
            cancellationToken);
        if (targetResult.Error is not null)
        {
            return targetResult.Error;
        }

        TrainingHistoryCursor? decodedCursor = null;
        if (cursor is not null)
        {
            if (!TrainingHistoryCursor.TryDecode(cursor, out var parsed))
            {
                return Results.BadRequest(new { error = "Invalid history cursor." });
            }
            decodedCursor = parsed;
        }

        var query = dbContext.SharedSessions
            .AsNoTracking()
            .Include(session => session.Values)
            .Where(session =>
                session.TraineeUserId == targetResult.TraineeUserId &&
                session.Status == SharedSessionStatus.Completed &&
                session.ClosedAt != null);

        SharedSession[] sessions;
        if (string.Equals(
                dbContext.Database.ProviderName,
                "Microsoft.EntityFrameworkCore.Sqlite",
                StringComparison.Ordinal))
        {
            var loaded = await query.ToListAsync(cancellationToken);
            var filtered = decodedCursor.HasValue
                ? loaded.Where(session => IsBeforeCursor(session, decodedCursor.Value))
                : loaded;
            sessions = filtered
                .OrderByDescending(session => session.ClosedAt)
                .ThenByDescending(session => session.Id)
                .Take(PageSize + 1)
                .ToArray();
        }
        else
        {
            if (decodedCursor.HasValue)
            {
                var cursorValue = decodedCursor.Value;
                query = query.Where(session =>
                    session.ClosedAt < cursorValue.CompletedAt ||
                    (session.ClosedAt == cursorValue.CompletedAt &&
                        session.Id.CompareTo(cursorValue.SessionId) < 0));
            }

            sessions = await query
                .OrderByDescending(session => session.ClosedAt)
                .ThenByDescending(session => session.Id)
                .Take(PageSize + 1)
                .ToArrayAsync(cancellationToken);
        }

        var hasNextPage = sessions.Length > PageSize;
        var page = sessions.Take(PageSize).ToArray();
        var nextCursor = hasNextPage
            ? new TrainingHistoryCursor(page[^1].ClosedAt!.Value, page[^1].Id).Encode()
            : null;

        return Results.Ok(new TrainingHistoryPageResponse(
            page.Select(ToSummary).ToArray(),
            nextCursor));
    }

    private static async Task<IResult> GetSession(
        Guid sessionId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var session = await dbContext.SharedSessions
            .AsNoTracking()
            .Include(item => item.Feedback)
            .Include(item => item.Values)
            .SingleOrDefaultAsync(item => item.Id == sessionId, cancellationToken);
        if (session is null || session.Status != SharedSessionStatus.Completed || session.ClosedAt is null)
        {
            return Results.NotFound();
        }

        if (!await TrainingHistoryAccess.CanAccessAsync(
                principal,
                session.TraineeUserId,
                dbContext,
                cancellationToken))
        {
            return Results.Forbid();
        }

        var exercises = GroupExercises(session.Values);
        return Results.Ok(new TrainingHistorySessionResponse(
            session.Id,
            session.WorkoutSetName,
            session.CreatedAt,
            session.ClosedAt.Value,
            DurationSeconds(session),
            exercises.Count,
            session.Values.Count,
            ToFeedback(session.Feedback),
            exercises));
    }

    private static async Task<IResult> GetExerciseProgress(
        Guid exerciseId,
        string? traineeUserId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var targetResult = await ResolveTargetAsync(
            principal,
            traineeUserId,
            dbContext,
            cancellationToken);
        if (targetResult.Error is not null)
        {
            return targetResult.Error;
        }

        var progressQuery = dbContext.SharedSessions
            .AsNoTracking()
            .Include(session => session.Values)
            .Where(session =>
                session.TraineeUserId == targetResult.TraineeUserId &&
                session.Status == SharedSessionStatus.Completed &&
                session.ClosedAt != null &&
                session.Values.Any(value => value.ExerciseId == exerciseId))
            ;
        List<SharedSession> sessions;
        if (string.Equals(
                dbContext.Database.ProviderName,
                "Microsoft.EntityFrameworkCore.Sqlite",
                StringComparison.Ordinal))
        {
            sessions = (await progressQuery.ToListAsync(cancellationToken))
                .OrderBy(session => session.ClosedAt)
                .ThenBy(session => session.Id)
                .ToList();
        }
        else
        {
            sessions = await progressQuery
                .OrderBy(session => session.ClosedAt)
                .ThenBy(session => session.Id)
                .ToListAsync(cancellationToken);
        }
        if (sessions.Count == 0)
        {
            return Results.NotFound();
        }

        var points = new List<ExerciseProgressPointResponse>();
        decimal? previous = null;
        string? exerciseName = null;
        string? exerciseType = null;
        foreach (var session in sessions)
        {
            var values = session.Values
                .Where(value => value.ExerciseId == exerciseId)
                .OrderBy(value => value.SetIndex)
                .ToArray();
            if (values.Length == 0)
            {
                continue;
            }

            exerciseName ??= values[0].ExerciseName;
            exerciseType ??= values[0].ExerciseType;
            var selected = MaximumValue(values[0].ExerciseType, values);
            points.Add(new ExerciseProgressPointResponse(
                session.Id,
                session.ClosedAt!.Value,
                selected,
                previous.HasValue ? selected - previous.Value : null));
            previous = selected;
        }

        if (points.Count == 0 || exerciseName is null || exerciseType is null)
        {
            return Results.NotFound();
        }

        var start = points[0].Value;
        var current = points[^1].Value;
        return Results.Ok(new ExerciseProgressResponse(
            exerciseId,
            exerciseName,
            exerciseType,
            Unit(exerciseType),
            start,
            current,
            current - start,
            points));
    }

    private static async Task<(string? TraineeUserId, IResult? Error)> ResolveTargetAsync(
        ClaimsPrincipal principal,
        string? requestedTraineeUserId,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var userId = TrainingHistoryAccess.UserId(principal);
        if (userId is null)
        {
            return (null, Results.Unauthorized());
        }

        string target;
        if (principal.HasClaim(ClaimTypes.Role, UserRole.Trainee))
        {
            target = string.IsNullOrWhiteSpace(requestedTraineeUserId)
                ? userId
                : requestedTraineeUserId;
        }
        else if (principal.HasClaim(ClaimTypes.Role, UserRole.Trainer))
        {
            if (string.IsNullOrWhiteSpace(requestedTraineeUserId))
            {
                return (null, Results.BadRequest(new { error = "Trainee user ID is required." }));
            }
            target = requestedTraineeUserId;
        }
        else
        {
            return (null, Results.Forbid());
        }

        if (!await TrainingHistoryAccess.CanAccessAsync(
                principal,
                target,
                dbContext,
                cancellationToken))
        {
            return (null, Results.Forbid());
        }

        return (target, null);
    }

    private static TrainingHistorySessionSummaryResponse ToSummary(SharedSession session)
    {
        return new TrainingHistorySessionSummaryResponse(
            session.Id,
            session.WorkoutSetName,
            session.CreatedAt,
            session.ClosedAt!.Value,
            DurationSeconds(session),
            ExerciseCount(session.Values),
            session.Values.Count);
    }

    private static IReadOnlyList<TrainingHistoryExerciseResponse> GroupExercises(
        IEnumerable<SharedSessionValue> values)
    {
        return values
            .GroupBy(value => new ExerciseGroupKey(
                value.ExerciseId,
                value.ExerciseOrder,
                value.ExerciseName,
                value.ExerciseType))
            .OrderBy(group => group.Key.ExerciseOrder)
            .ThenBy(group => group.Key.ExerciseName)
            .Select(group =>
            {
                var ordered = group.OrderBy(value => value.SetIndex).ThenBy(value => value.Id).ToArray();
                return new TrainingHistoryExerciseResponse(
                    group.Key.ExerciseId,
                    group.Key.ExerciseName,
                    group.Key.ExerciseType,
                    group.Key.ExerciseOrder,
                    MaximumValue(group.Key.ExerciseType, ordered),
                    ordered.Select(value => new TrainingHistorySeriesResponse(
                        value.SetIndex,
                        value.Reps,
                        value.Weight,
                        value.Seconds)).ToArray());
            })
            .ToArray();
    }

    private static TrainingHistoryFeedbackResponse? ToFeedback(PostWorkoutFeedback? feedback)
    {
        return feedback is null
            ? null
            : new TrainingHistoryFeedbackResponse(
                feedback.WellbeingRating,
                feedback.Comment,
                feedback.SubmittedAt);
    }

    private static int ExerciseCount(IEnumerable<SharedSessionValue> values)
    {
        return values
            .Select(value => new ExerciseGroupKey(
                value.ExerciseId,
                value.ExerciseOrder,
                value.ExerciseName,
                value.ExerciseType))
            .Distinct()
            .Count();
    }

    private static int DurationSeconds(SharedSession session)
    {
        return Math.Max(0, (int)(session.ClosedAt!.Value - session.CreatedAt).TotalSeconds);
    }

    private static bool IsBeforeCursor(
        SharedSession session,
        TrainingHistoryCursor cursor)
    {
        return session.ClosedAt < cursor.CompletedAt ||
            (session.ClosedAt == cursor.CompletedAt &&
                session.Id.CompareTo(cursor.SessionId) < 0);
    }

    private static decimal MaximumValue(
        string exerciseType,
        IReadOnlyCollection<SharedSessionValue> values)
    {
        return exerciseType switch
        {
            ExerciseValueType.RepsWeight => values.Max(value => value.Weight) ?? 0m,
            ExerciseValueType.RepsOnly => values.Max(value => value.Reps) ?? 0,
            ExerciseValueType.Time => values.Max(value => value.Seconds) ?? 0,
            _ => 0m,
        };
    }

    private static string Unit(string exerciseType)
    {
        return exerciseType switch
        {
            ExerciseValueType.RepsWeight => "kg",
            ExerciseValueType.RepsOnly => "powt.",
            ExerciseValueType.Time => "s",
            _ => string.Empty,
        };
    }

    private readonly record struct ExerciseGroupKey(
        Guid? ExerciseId,
        int ExerciseOrder,
        string ExerciseName,
        string ExerciseType);
}
