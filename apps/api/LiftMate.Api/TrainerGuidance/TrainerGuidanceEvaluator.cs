using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.TrainerGuidance;

public sealed class TrainerGuidanceEvaluator(ApplicationDbContext dbContext)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task EvaluateWeightStagnationAsync(
        string traineeUserId,
        CancellationToken cancellationToken)
    {
        var sessions = await dbContext.SharedSessions
            .AsNoTracking()
            .Include(session => session.Values)
            .Where(session =>
                session.TraineeUserId == traineeUserId &&
                session.Status == SharedSessionStatus.Completed &&
                session.ClosedAt != null)
            .ToListAsync(cancellationToken);

        var windows = sessions
            .OrderByDescending(session => session.ClosedAt)
            .ThenByDescending(session => session.Id)
            .SelectMany(session => session.Values
                .Where(value =>
                    value.ExerciseId != null &&
                    value.ExerciseType == ExerciseValueType.RepsWeight &&
                    value.Weight != null)
                .GroupBy(value => value.ExerciseId!.Value)
                .Select(group => new WeightSessionPoint(
                    group.Key,
                    session.Id,
                    session.ClosedAt!.Value,
                    group.OrderBy(value => value.ExerciseOrder).ThenBy(value => value.SetIndex).ThenBy(value => value.Id).Last().ExerciseName,
                    group.Max(value => value.Weight!.Value))))
            .GroupBy(point => point.ExerciseId);

        foreach (var exerciseWindow in windows)
        {
            var latestThree = exerciseWindow
                .OrderByDescending(point => point.ClosedAt)
                .ThenByDescending(point => point.SessionId)
                .Take(3)
                .ToArray();

            if (latestThree.Length < 3)
            {
                continue;
            }

            var newest = latestThree[0];
            var oldest = latestThree[2];
            if (newest.MaxWeight > oldest.MaxWeight)
            {
                continue;
            }

            var chronological = latestThree
                .OrderBy(point => point.ClosedAt)
                .ThenBy(point => point.SessionId)
                .ToArray();
            var evidence = new
            {
                sessions = chronological.Select(point => new
                {
                    sessionId = point.SessionId,
                    closedAt = point.ClosedAt,
                    maxWeight = point.MaxWeight,
                }),
            };
            var fingerprint = Fingerprint(
                traineeUserId,
                TrainerGuidanceType.WeightStagnation,
                exerciseWindow.Key.ToString(),
                chronological.Select(point => $"{point.SessionId}:{point.MaxWeight:0.##}"));

            await AddIfMissingAsync(
                traineeUserId,
                TrainerGuidanceType.WeightStagnation,
                exerciseWindow.Key,
                newest.ExerciseName,
                fingerprint,
                $"Warto sprawdzić ciężar w ćwiczeniu {newest.ExerciseName}",
                JsonSerializer.Serialize(evidence, JsonOptions),
                cancellationToken);
        }
    }

    public async Task EvaluateLowWellbeingAsync(
        string traineeUserId,
        CancellationToken cancellationToken)
    {
        var feedbackSessions = await dbContext.SharedSessions
            .AsNoTracking()
            .Include(session => session.Feedback)
            .Where(session =>
                session.TraineeUserId == traineeUserId &&
                session.Status == SharedSessionStatus.Completed &&
                session.ClosedAt != null &&
                session.Feedback != null)
            .ToListAsync(cancellationToken);

        var feedbackWindow = feedbackSessions
            .OrderByDescending(session => session.ClosedAt)
            .ThenByDescending(session => session.Id)
            .Take(3)
            .Select(session => new FeedbackSessionPoint(
                session.Id,
                session.ClosedAt!.Value,
                session.Feedback!.WellbeingRating))
            .ToArray();

        if (feedbackWindow.Length < 3)
        {
            return;
        }

        var average = Math.Round(
            feedbackWindow.Average(point => (decimal)point.Rating),
            1,
            MidpointRounding.AwayFromZero);
        var averageText = average.ToString("0.0", CultureInfo.InvariantCulture);
        if (average > 3.0m)
        {
            return;
        }

        var chronological = feedbackWindow
            .OrderBy(point => point.ClosedAt)
            .ThenBy(point => point.SessionId)
            .ToArray();
        var evidence = new
        {
            averageRating = average,
            sessions = chronological.Select(point => new
            {
                sessionId = point.SessionId,
                closedAt = point.ClosedAt,
                rating = point.Rating,
            }),
        };
        var fingerprint = Fingerprint(
            traineeUserId,
            TrainerGuidanceType.LowWellbeing,
            "wellbeing",
            chronological.Select(point => $"{point.SessionId}:{point.Rating}"),
            averageText);

        await AddIfMissingAsync(
            traineeUserId,
            TrainerGuidanceType.LowWellbeing,
            exerciseId: null,
            exerciseName: null,
            fingerprint,
            $"Średnia ocena samopoczucia z ostatnich treningów wynosi {averageText}/5",
            JsonSerializer.Serialize(evidence, JsonOptions),
            cancellationToken);
    }

    private async Task AddIfMissingAsync(
        string traineeUserId,
        string type,
        Guid? exerciseId,
        string? exerciseName,
        string fingerprint,
        string message,
        string evidenceJson,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.TrainerGuidance.AnyAsync(
            item =>
                item.TraineeUserId == traineeUserId &&
                item.Type == type &&
                item.ExerciseId == exerciseId &&
                item.Fingerprint == fingerprint,
            cancellationToken);
        if (exists)
        {
            return;
        }

        dbContext.TrainerGuidance.Add(new TrainerGuidance
        {
            Id = Guid.NewGuid(),
            TraineeUserId = traineeUserId,
            Type = type,
            ExerciseId = exerciseId,
            ExerciseName = exerciseName,
            Fingerprint = fingerprint,
            Message = message,
            EvidenceJson = evidenceJson,
            CreatedAt = DateTimeOffset.UtcNow,
        });

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            dbContext.ChangeTracker.Clear();
            if (!await dbContext.TrainerGuidance.AnyAsync(
                    item =>
                        item.TraineeUserId == traineeUserId &&
                        item.Type == type &&
                        item.ExerciseId == exerciseId &&
                        item.Fingerprint == fingerprint,
                    cancellationToken))
            {
                throw;
            }
        }
    }

    private static string Fingerprint(
        string traineeUserId,
        string type,
        string scope,
        IEnumerable<string> evidence,
        string? aggregate = null)
    {
        var raw = string.Join("|", [traineeUserId, type, scope, .. evidence, aggregate ?? string.Empty]);
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(raw));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    private sealed record WeightSessionPoint(
        Guid ExerciseId,
        Guid SessionId,
        DateTimeOffset ClosedAt,
        string ExerciseName,
        decimal MaxWeight);

    private sealed record FeedbackSessionPoint(
        Guid SessionId,
        DateTimeOffset ClosedAt,
        int Rating);
}
