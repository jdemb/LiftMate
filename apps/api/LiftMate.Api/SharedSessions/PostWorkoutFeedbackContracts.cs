namespace LiftMate.Api.SharedSessions;

public sealed record CreatePostWorkoutFeedbackRequest(
    int WellbeingRating,
    string? Comment);

public sealed record PostWorkoutFeedbackResponse(
    Guid SharedSessionId,
    int WellbeingRating,
    string? Comment,
    DateTimeOffset SubmittedAt);
