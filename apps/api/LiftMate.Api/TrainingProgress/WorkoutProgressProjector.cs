using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.TrainingProgress;

public sealed class WorkoutProgressProjector(ApplicationDbContext dbContext)
{
    public async Task ProjectAsync(
        SharedSession session,
        DateTimeOffset completedAt,
        CancellationToken cancellationToken)
    {
        if (!session.WorkoutSetId.HasValue ||
            session.Values.Count == 0 ||
            session.Values.Any(value => !value.ExerciseId.HasValue || !value.WorkoutSetRowId.HasValue))
        {
            return;
        }

        var progress = await dbContext.WorkoutProgresses
            .Include(item => item.Values)
            .SingleOrDefaultAsync(
                item =>
                    item.TraineeUserId == session.TraineeUserId &&
                    item.WorkoutSetId == session.WorkoutSetId.Value,
                cancellationToken);

        if (progress is not null && completedAt <= progress.SourceCompletedAt)
        {
            return;
        }

        if (progress is null)
        {
            progress = new WorkoutProgress
            {
                Id = Guid.NewGuid(),
                TraineeUserId = session.TraineeUserId,
                WorkoutSetId = session.WorkoutSetId.Value,
            };
            dbContext.WorkoutProgresses.Add(progress);
        }

        progress.SourceSessionId = session.Id;
        progress.SourceCompletedAt = completedAt;
        progress.UpdatedAt = completedAt;

        var obsoleteValues = progress.Values
            .ToDictionary(value => value.WorkoutSetRowId);
        foreach (var value in session.Values)
        {
            if (!obsoleteValues.Remove(value.WorkoutSetRowId!.Value, out var projectedValue))
            {
                projectedValue = new WorkoutProgressValue
                {
                    Id = Guid.NewGuid(),
                    WorkoutSetRowId = value.WorkoutSetRowId.Value,
                };
                progress.Values.Add(projectedValue);
            }

            projectedValue.ExerciseId = value.ExerciseId!.Value;
            projectedValue.ExerciseType = value.ExerciseType;
            projectedValue.Reps = value.Reps;
            projectedValue.Weight = value.Weight;
            projectedValue.Seconds = value.Seconds;
        }

        dbContext.WorkoutProgressValues.RemoveRange(obsoleteValues.Values);
    }
}
