using LiftMate.Api.Auth;

namespace LiftMate.Api.WeeklyStreaks;

public sealed class TraineeWeeklyStreak
{
    public required string TraineeUserId { get; set; }

    public DateOnly? LastActiveWeekStart { get; set; }

    public int CurrentStreakAtLastActiveWeek { get; set; }

    public int BestStreak { get; set; }

    public DateTimeOffset? LastCompletedSessionAt { get; set; }

    public DateTimeOffset CalculatedAt { get; set; }

    public ApplicationUser TraineeUser { get; set; } = null!;
}
