using LiftMate.Api.Auth;

namespace LiftMate.Api.SharedSessions;

public sealed class SharedSession
{
    public Guid Id { get; set; }

    public string TrainerUserId { get; set; } = string.Empty;

    public ApplicationUser? TrainerUser { get; set; }

    public string TraineeUserId { get; set; } = string.Empty;

    public ApplicationUser? TraineeUser { get; set; }

    public string Status { get; set; } = SharedSessionStatus.Active;

    public long Version { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? ClosedAt { get; set; }

    public ICollection<SharedSessionValue> Values { get; } = new List<SharedSessionValue>();
}
