namespace LiftMate.Api.WeeklyStreaks;

public sealed record WeeklyStreakCalculation(
    DateOnly? LastActiveWeekStart,
    int CurrentStreakAtLastActiveWeek,
    int BestStreak,
    DateTimeOffset? LastCompletedSessionAt,
    DateTimeOffset CalculatedAt);

public sealed record WeeklyStreakResponse(
    int CurrentStreak,
    int BestStreak,
    DateOnly? LastActiveWeekStart,
    DateTimeOffset? LastCompletedWorkoutAt,
    bool IsActiveThisWeek);
