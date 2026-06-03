namespace LiftMate.Api.SharedSessions;

public sealed record CreateSharedSessionRequest(
    string TraineeUserId,
    IReadOnlyList<CreateSharedSessionValueRequest> Values);

public sealed record CreateSharedSessionValueRequest(
    string ExerciseName,
    string ExerciseType,
    int SetIndex,
    int? Reps,
    decimal? Weight,
    int? Seconds);

public sealed record UpdateSharedSessionValueRequest(
    int? Reps,
    decimal? Weight,
    int? Seconds);

public sealed record SharedSessionResponse(
    Guid Id,
    string TrainerUserId,
    string TraineeUserId,
    string Status,
    long Version,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? ClosedAt,
    IReadOnlyList<SharedSessionValueResponse> Values);

public sealed record SharedSessionValueResponse(
    Guid Id,
    string ExerciseName,
    string ExerciseType,
    int SetIndex,
    int? Reps,
    decimal? Weight,
    int? Seconds,
    string? UpdatedByUserId,
    DateTimeOffset? UpdatedAt);
