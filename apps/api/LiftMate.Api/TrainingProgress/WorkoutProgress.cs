using LiftMate.Api.WorkoutSets;

namespace LiftMate.Api.TrainingProgress;

public sealed class WorkoutProgress
{
    public Guid Id { get; set; }

    public string TraineeUserId { get; set; } = string.Empty;

    public Guid WorkoutSetId { get; set; }

    public WorkoutSet? WorkoutSet { get; set; }

    public Guid SourceSessionId { get; set; }

    public DateTimeOffset SourceCompletedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public ICollection<WorkoutProgressValue> Values { get; } = new List<WorkoutProgressValue>();
}
