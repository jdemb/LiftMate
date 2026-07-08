namespace LiftMate.Api.SharedSessions;

public sealed record CreateSharedSessionRequest(
    string TraineeEmail,
    IReadOnlyList<CreateSharedSessionValueRequest> Values);

public sealed record CreateSharedSessionValueRequest(
    string ExerciseName,
    string ExerciseType,
    int SetIndex,
    int? Reps,
    decimal? Weight,
    int? Seconds);

public sealed record StartSharedSessionFromWorkoutSetRequest(
    Guid WorkoutSetId,
    string? TraineeUserId);

public sealed record UpdateSharedSessionValueRequest(
    int? Reps,
    decimal? Weight,
    int? Seconds,
    bool? IsDone);

public sealed record UpdateSharedSessionRestRequest(
    string Action,
    int? DeltaSeconds);

public sealed record SharedSessionResponse(
    Guid Id,
    string TrainerUserId,
    string TraineeUserId,
    string TrainerEmail,
    string TraineeEmail,
    Guid? WorkoutSetId,
    string WorkoutSetName,
    int RestSeconds,
    string StartedByUserId,
    string StartedByRole,
    string Status,
    long Version,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? ClosedAt,
    SharedSessionRestTimerResponse RestTimer,
    IReadOnlyList<SharedSessionValueResponse> Values);

public sealed record SharedSessionRestTimerResponse(
    int TotalSeconds,
    int RemainingSeconds,
    DateTimeOffset? EndsAt,
    DateTimeOffset ServerNow);

public sealed record SharedSessionValueResponse(
    Guid Id,
    Guid? ExerciseId,
    Guid? WorkoutSetRowId,
    string ExerciseName,
    string ExerciseType,
    int ExerciseOrder,
    int SetIndex,
    int? Reps,
    decimal? Weight,
    int? Seconds,
    bool IsDone,
    DateTimeOffset? CompletedAt,
    string? UpdatedByUserId,
    DateTimeOffset? UpdatedAt);
