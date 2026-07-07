namespace LiftMate.Api.SharedSessions;

public static class SharedSessionMapping
{
    public static SharedSessionResponse ToResponse(SharedSession session)
    {
        var serverNow = DateTimeOffset.UtcNow;
        var remainingSeconds = session.RestTimerEndsAt is null
            ? session.RestTimerRemainingSeconds
            : (int)Math.Ceiling((session.RestTimerEndsAt.Value - serverNow).TotalSeconds);
        remainingSeconds = Math.Clamp(remainingSeconds, 0, 3600);

        return new SharedSessionResponse(
            session.Id,
            session.TrainerUserId,
            session.TraineeUserId,
            session.TrainerUser?.Email ?? string.Empty,
            session.TraineeUser?.Email ?? string.Empty,
            session.WorkoutSetId,
            session.WorkoutSetName,
            session.RestSeconds,
            session.StartedByUserId,
            session.StartedByRole,
            session.Status,
            session.Version,
            session.CreatedAt,
            session.UpdatedAt,
            session.ClosedAt,
            new SharedSessionRestTimerResponse(
                Math.Clamp(session.RestTimerTotalSeconds, 0, 3600),
                remainingSeconds,
                session.RestTimerEndsAt,
                serverNow),
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
            value.ExerciseId,
            value.WorkoutSetRowId,
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
