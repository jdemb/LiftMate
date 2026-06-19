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
        else
        {
            dbContext.WorkoutProgressValues.RemoveRange(progress.Values);
        }

        progress.SourceSessionId = session.Id;
        progress.SourceCompletedAt = completedAt;
        progress.UpdatedAt = completedAt;

        foreach (var value in session.Values)
        {
            progress.Values.Add(new WorkoutProgressValue
            {
                Id = Guid.NewGuid(),
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
