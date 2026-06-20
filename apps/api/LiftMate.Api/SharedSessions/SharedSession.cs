using LiftMate.Api.Auth;
using LiftMate.Api.WorkoutSets;

namespace LiftMate.Api.SharedSessions;

public sealed class SharedSession
{
    public Guid Id { get; set; }

    public string TrainerUserId { get; set; } = string.Empty;

    public ApplicationUser? TrainerUser { get; set; }

    public string TraineeUserId { get; set; } = string.Empty;

    public ApplicationUser? TraineeUser { get; set; }

    public Guid? WorkoutSetId { get; set; }

    public WorkoutSet? WorkoutSet { get; set; }

    public string WorkoutSetName { get; set; } = "Trening";

    public int RestSeconds { get; set; } = 90;

    public string StartedByUserId { get; set; } = string.Empty;

    public ApplicationUser? StartedByUser { get; set; }

    public string StartedByRole { get; set; } = UserRole.Trainer;

    public string Status { get; set; } = SharedSessionStatus.Active;

    public long Version { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? ClosedAt { get; set; }

    public ICollection<SharedSessionValue> Values { get; } = new List<SharedSessionValue>();
}
