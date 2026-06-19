namespace LiftMate.Api.WorkoutSets;

public sealed class WorkoutSetRow
{
    public Guid Id { get; set; }

    public Guid WorkoutSetId { get; set; }

    public WorkoutSet? WorkoutSet { get; set; }

    public Guid ExerciseId { get; set; }

    public int ExerciseOrder { get; set; }

    public int SetIndex { get; set; }

    public string ExerciseName { get; set; } = string.Empty;

    public string ExerciseType { get; set; } = string.Empty;

    public int? Reps { get; set; }

    public decimal? Weight { get; set; }

    public int? Seconds { get; set; }
}
