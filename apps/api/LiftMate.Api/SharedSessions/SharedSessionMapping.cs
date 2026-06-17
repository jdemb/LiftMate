namespace LiftMate.Api.SharedSessions;

public static class SharedSessionMapping
{
    public static SharedSessionResponse ToResponse(SharedSession session)
    {
        return new SharedSessionResponse(
            session.Id,
            session.TrainerUserId,
            session.TraineeUserId,
            session.TrainerUser?.Email ?? string.Empty,
            session.TraineeUser?.Email ?? string.Empty,
            session.WorkoutSetId,
            session.StartedByUserId,
            session.StartedByRole,
            session.Status,
            session.Version,
            session.CreatedAt,
            session.UpdatedAt,
            session.ClosedAt,
            session.Values
                .OrderBy(value => value.ExerciseOrder)
                .ThenBy(value => value.SetIndex)
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
            value.ExerciseOrder,
            value.SetIndex,
            value.Reps,
            value.Weight,
            value.Seconds,
            value.IsDone,
            value.CompletedAt,
            value.UpdatedByUserId,
            value.UpdatedAt);
    }
}
