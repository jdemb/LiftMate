using LiftMate.Api.Auth;

namespace LiftMate.Api.SharedSessions;

public sealed class SharedSessionValue
{
    public Guid Id { get; set; }

    public Guid SharedSessionId { get; set; }

    public SharedSession? SharedSession { get; set; }

    public string ExerciseName { get; set; } = string.Empty;

    public string ExerciseType { get; set; } = string.Empty;

    public int ExerciseOrder { get; set; }

    public int SetIndex { get; set; }

    public int? Reps { get; set; }

    public decimal? Weight { get; set; }

    public int? Seconds { get; set; }

    public bool IsDone { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    public string? UpdatedByUserId { get; set; }

    public ApplicationUser? UpdatedByUser { get; set; }

    public DateTimeOffset? UpdatedAt { get; set; }
}
