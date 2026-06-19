namespace LiftMate.Api.TrainingProgress;

public sealed class WorkoutProgressValue
{
    public Guid Id { get; set; }

    public Guid WorkoutProgressId { get; set; }

    public WorkoutProgress? WorkoutProgress { get; set; }

    public Guid WorkoutSetRowId { get; set; }

    public Guid ExerciseId { get; set; }

    public string ExerciseType { get; set; } = string.Empty;

    public int? Reps { get; set; }

    public decimal? Weight { get; set; }

    public int? Seconds { get; set; }
}
