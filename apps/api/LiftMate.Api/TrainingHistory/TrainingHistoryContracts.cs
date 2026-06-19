namespace LiftMate.Api.TrainingHistory;

public sealed record TrainingHistoryPageResponse(
    IReadOnlyList<TrainingHistorySessionSummaryResponse> Items,
    string? NextCursor);

public sealed record TrainingHistorySessionSummaryResponse(
    Guid Id,
    string WorkoutSetName,
    DateTimeOffset StartedAt,
    DateTimeOffset CompletedAt,
    int DurationSeconds,
    int ExerciseCount,
    int SeriesCount);

public sealed record TrainingHistorySessionResponse(
    Guid Id,
    string WorkoutSetName,
    DateTimeOffset StartedAt,
    DateTimeOffset CompletedAt,
    int DurationSeconds,
    int ExerciseCount,
    int SeriesCount,
    IReadOnlyList<TrainingHistoryExerciseResponse> Exercises);

public sealed record TrainingHistoryExerciseResponse(
    Guid? ExerciseId,
    string ExerciseName,
    string ExerciseType,
    int ExerciseOrder,
    decimal MaximumValue,
    IReadOnlyList<TrainingHistorySeriesResponse> Series);

public sealed record TrainingHistorySeriesResponse(
    int SetIndex,
    int? Reps,
    decimal? Weight,
    int? Seconds);

public sealed record ExerciseProgressResponse(
    Guid ExerciseId,
    string ExerciseName,
    string ExerciseType,
    string Unit,
    decimal StartValue,
    decimal CurrentValue,
    decimal OverallDelta,
    IReadOnlyList<ExerciseProgressPointResponse> Points);

public sealed record ExerciseProgressPointResponse(
    Guid SessionId,
    DateTimeOffset CompletedAt,
    decimal Value,
    decimal? Delta);
