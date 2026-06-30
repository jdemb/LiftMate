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

        var existingProgress = await dbContext.WorkoutProgresses
            .AsNoTracking()
            .Where(item =>
                item.TraineeUserId == session.TraineeUserId &&
                item.WorkoutSetId == session.WorkoutSetId.Value)
            .Select(item => new
            {
                item.Id,
                item.SourceCompletedAt,
            })
            .SingleOrDefaultAsync(cancellationToken);

        if (existingProgress is not null && completedAt <= existingProgress.SourceCompletedAt)
        {
            return;
        }

        Guid progressId;
        if (existingProgress is null)
        {
            progressId = Guid.NewGuid();
            dbContext.WorkoutProgresses.Add(new WorkoutProgress
            {
                Id = progressId,
                TraineeUserId = session.TraineeUserId,
                WorkoutSetId = session.WorkoutSetId.Value,
                SourceSessionId = session.Id,
                SourceCompletedAt = completedAt,
                UpdatedAt = completedAt,
            });
        }
        else
        {
            progressId = existingProgress.Id;
            var updatedProgressCount = await dbContext.WorkoutProgresses
                .Where(item => item.Id == progressId)
                .ExecuteUpdateAsync(
                    setters => setters
                        .SetProperty(item => item.SourceSessionId, session.Id)
                        .SetProperty(item => item.SourceCompletedAt, completedAt)
                        .SetProperty(item => item.UpdatedAt, completedAt),
                    cancellationToken);

            if (updatedProgressCount != 1)
            {
                throw new InvalidOperationException(
                    $"Workout progress {progressId} disappeared during projection.");
            }

            await dbContext.WorkoutProgressValues
                .Where(value => value.WorkoutProgressId == progressId)
                .ExecuteDeleteAsync(cancellationToken);
        }

        foreach (var value in session.Values)
        {
            dbContext.WorkoutProgressValues.Add(new WorkoutProgressValue
            {
                Id = Guid.NewGuid(),
                WorkoutProgressId = progressId,
                WorkoutSetRowId = value.WorkoutSetRowId!.Value,
                ExerciseId = value.ExerciseId!.Value,
                ExerciseType = value.ExerciseType,
                Reps = value.Reps,
                Weight = value.Weight,
                Seconds = value.Seconds,
            });
        }
    }
}
