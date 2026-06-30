namespace LiftMate.Api.WeeklyStreaks;

public static class WeeklyStreakCalculator
{
    private static readonly TimeZoneInfo WarsawTimeZone = ResolveWarsawTimeZone();

    public static WeeklyStreakCalculation Calculate(
        IEnumerable<DateTimeOffset> completedSessions,
        DateTimeOffset calculatedAt)
    {
        var completedAt = completedSessions.OrderBy(value => value).ToArray();
        if (completedAt.Length == 0)
        {
            return new WeeklyStreakCalculation(null, 0, 0, null, calculatedAt);
        }

        var activeWeeks = completedAt
            .Select(GetWeekStart)
            .Distinct()
            .OrderBy(value => value)
            .ToArray();

        var currentRun = 0;
        var bestRun = 0;
        DateOnly? previousWeek = null;

        foreach (var week in activeWeeks)
        {
            currentRun = previousWeek is not null && previousWeek.Value.AddDays(7) == week
                ? currentRun + 1
                : 1;
            bestRun = Math.Max(bestRun, currentRun);
            previousWeek = week;
        }

        return new WeeklyStreakCalculation(
            activeWeeks[^1],
            currentRun,
            bestRun,
            completedAt[^1],
            calculatedAt);
    }

    public static WeeklyStreakResponse ToResponse(
        TraineeWeeklyStreak? snapshot,
        DateTimeOffset now)
    {
        if (snapshot?.LastActiveWeekStart is null)
        {
            return new WeeklyStreakResponse(0, 0, null, null, false);
        }

        var currentWeekStart = GetWeekStart(now);
        var lastActiveWeekStart = snapshot.LastActiveWeekStart.Value;
        var isActiveThisWeek = lastActiveWeekStart == currentWeekStart;
        var isPreviousWeek = lastActiveWeekStart == currentWeekStart.AddDays(-7);

        return new WeeklyStreakResponse(
            isActiveThisWeek || isPreviousWeek
                ? snapshot.CurrentStreakAtLastActiveWeek
                : 0,
            snapshot.BestStreak,
            lastActiveWeekStart,
            snapshot.LastCompletedSessionAt,
            isActiveThisWeek);
    }

    public static DateOnly GetWeekStart(DateTimeOffset timestamp)
    {
        var localTimestamp = TimeZoneInfo.ConvertTime(timestamp, WarsawTimeZone);
        var localDate = DateOnly.FromDateTime(localTimestamp.DateTime);
        var daysSinceMonday = ((int)localDate.DayOfWeek - (int)DayOfWeek.Monday + 7) % 7;
        return localDate.AddDays(-daysSinceMonday);
    }

    private static TimeZoneInfo ResolveWarsawTimeZone()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Europe/Warsaw");
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Central European Standard Time");
        }
    }
}
