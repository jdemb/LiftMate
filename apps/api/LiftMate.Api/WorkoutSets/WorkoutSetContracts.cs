namespace LiftMate.Api.WorkoutSets;

public sealed record CreateWorkoutSetRequest(
    string Name,
    IReadOnlyList<WorkoutSetRowRequest> Rows);

public sealed record UpdateWorkoutSetRequest(
    string Name,
    IReadOnlyList<WorkoutSetRowRequest> Rows);

public sealed record WorkoutSetRowRequest(
    int ExerciseOrder,
    int SetIndex,
    string ExerciseName,
    string ExerciseType,
    int? Reps,
    decimal? Weight,
    int? Seconds,
    Guid? Id = null,
    Guid? ExerciseId = null);

public sealed record AssignWorkoutSetRequest(IReadOnlyList<string> TraineeUserIds);

public sealed record WorkoutSetSummaryResponse(
    Guid Id,
    string Name,
    int ExerciseCount,
    int RowCount,
    int AssignedTrainees,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record WorkoutSetDetailResponse(
    Guid Id,
    string Name,
    IReadOnlyList<WorkoutSetRowResponse> Rows,
    IReadOnlyList<WorkoutSetAssignmentResponse> Assignments,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record WorkoutSetRowResponse(
    Guid Id,
    Guid ExerciseId,
    int ExerciseOrder,
    int SetIndex,
    string ExerciseName,
    string ExerciseType,
    int? Reps,
    decimal? Weight,
    int? Seconds);

public sealed record WorkoutSetAssignmentResponse(
    string TraineeUserId,
    string TraineeEmail,
    string TraineeDisplayName,
    DateTimeOffset AssignedAt);

public sealed record TraineeAssignedWorkoutSetResponse(
    Guid Id,
    string Name,
    string TrainerDisplayName,
    IReadOnlyList<WorkoutSetRowResponse> Rows,
    DateTimeOffset AssignedAt,
    DateTimeOffset UpdatedAt);
