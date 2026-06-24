namespace LiftMate.Api.SharedSessions;

public sealed class PostWorkoutFeedback
{
    public Guid SharedSessionId { get; set; }

    public SharedSession? SharedSession { get; set; }

    public int WellbeingRating { get; set; }

    public string? Comment { get; set; }

    public DateTimeOffset SubmittedAt { get; set; }
}
