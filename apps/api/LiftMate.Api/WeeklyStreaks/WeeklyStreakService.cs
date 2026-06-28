using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.WeeklyStreaks;

public sealed class WeeklyStreakService(
    ApplicationDbContext dbContext,
    TimeProvider timeProvider)
{
    public async Task<TraineeWeeklyStreak?> RecalculateForTraineeAsync(
        string traineeUserId,
        CancellationToken cancellationToken = default)
    {
        var completedAt = await dbContext.SharedSessions
            .Where(session =>
                session.TraineeUserId == traineeUserId &&
                session.Status == SharedSessionStatus.Completed &&
                session.ClosedAt != null)
            .Select(session => session.ClosedAt!.Value)
            .ToListAsync(cancellationToken);

        var existing = await dbContext.TraineeWeeklyStreaks
            .SingleOrDefaultAsync(
                streak => streak.TraineeUserId == traineeUserId,
                cancellationToken);

        if (completedAt.Count == 0)
        {
            if (existing is not null)
            {
                dbContext.TraineeWeeklyStreaks.Remove(existing);
                await dbContext.SaveChangesAsync(cancellationToken);
            }

            return null;
        }

        var snapshot = ApplyCalculation(
            traineeUserId,
            existing,
            WeeklyStreakCalculator.Calculate(completedAt, timeProvider.GetUtcNow()));
        await dbContext.SaveChangesAsync(cancellationToken);
        return snapshot;
    }

    public async Task<WeeklyStreakResponse> GetResponseForTraineeAsync(
        string traineeUserId,
        CancellationToken cancellationToken = default)
    {
        var responses = await GetResponsesForTraineesAsync(
            [traineeUserId],
            cancellationToken);
        return responses[traineeUserId];
    }

    public async Task<IReadOnlyDictionary<string, WeeklyStreakResponse>> GetResponsesForTraineesAsync(
        IReadOnlyCollection<string> traineeUserIds,
        CancellationToken cancellationToken = default)
    {
        var ids = traineeUserIds
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
        if (ids.Length == 0)
        {
            return new Dictionary<string, WeeklyStreakResponse>();
        }

        var snapshots = await dbContext.TraineeWeeklyStreaks
            .Where(streak => ids.Contains(streak.TraineeUserId))
            .ToDictionaryAsync(streak => streak.TraineeUserId, cancellationToken);

        var completedRows = await dbContext.SharedSessions
            .Where(session =>
                ids.Contains(session.TraineeUserId) &&
                session.Status == SharedSessionStatus.Completed &&
                session.ClosedAt != null)
            .Select(session => new
            {
                session.TraineeUserId,
                CompletedAt = session.ClosedAt!.Value,
            })
            .ToListAsync(cancellationToken);
        var latestCompleted = completedRows
            .GroupBy(row => row.TraineeUserId)
            .Select(group => group.OrderByDescending(row => row.CompletedAt).First())
            .ToArray();

        var staleIds = latestCompleted
            .Where(latest =>
                !snapshots.TryGetValue(latest.TraineeUserId, out var snapshot) ||
                snapshot.LastCompletedSessionAt != latest.CompletedAt)
            .Select(latest => latest.TraineeUserId)
            .ToArray();

        if (staleIds.Length > 0)
        {
            var now = timeProvider.GetUtcNow();

            foreach (var group in completedRows
                .Where(row => staleIds.Contains(row.TraineeUserId))
                .GroupBy(row => row.TraineeUserId))
            {
                snapshots.TryGetValue(group.Key, out var existing);
                snapshots[group.Key] = ApplyCalculation(
                    group.Key,
                    existing,
                    WeeklyStreakCalculator.Calculate(
                        group.Select(row => row.CompletedAt),
                        now));
            }

            await dbContext.SaveChangesAsync(cancellationToken);
        }

        var responseNow = timeProvider.GetUtcNow();
        return ids.ToDictionary(
            id => id,
            id => WeeklyStreakCalculator.ToResponse(
                snapshots.GetValueOrDefault(id),
                responseNow),
            StringComparer.Ordinal);
    }

    private TraineeWeeklyStreak ApplyCalculation(
        string traineeUserId,
        TraineeWeeklyStreak? snapshot,
        WeeklyStreakCalculation calculation)
    {
        snapshot ??= new TraineeWeeklyStreak { TraineeUserId = traineeUserId };
        snapshot.LastActiveWeekStart = calculation.LastActiveWeekStart;
        snapshot.CurrentStreakAtLastActiveWeek = calculation.CurrentStreakAtLastActiveWeek;
        snapshot.BestStreak = calculation.BestStreak;
        snapshot.LastCompletedSessionAt = calculation.LastCompletedSessionAt;
        snapshot.CalculatedAt = calculation.CalculatedAt;

        if (dbContext.Entry(snapshot).State == EntityState.Detached)
        {
            dbContext.TraineeWeeklyStreaks.Add(snapshot);
        }

        return snapshot;
    }
}
