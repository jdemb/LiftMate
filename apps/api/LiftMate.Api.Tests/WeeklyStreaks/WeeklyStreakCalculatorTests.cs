using LiftMate.Api.WeeklyStreaks;

namespace LiftMate.Api.Tests.WeeklyStreaks;

public sealed class WeeklyStreakCalculatorTests
{
    private static readonly DateTimeOffset WednesdayNow =
        new(2026, 6, 24, 10, 0, 0, TimeSpan.Zero);

    [Fact]
    public void CalculateCountsOneCompletedWorkoutInCurrentWeek()
    {
        var result = WeeklyStreakCalculator.Calculate(
            [new DateTimeOffset(2026, 6, 23, 18, 0, 0, TimeSpan.Zero)],
            WednesdayNow);

        Assert.Equal(new DateOnly(2026, 6, 22), result.LastActiveWeekStart);
        Assert.Equal(1, result.CurrentStreakAtLastActiveWeek);
        Assert.Equal(1, result.BestStreak);
    }

    [Fact]
    public void CalculateCountsMultipleWorkoutsInOneWeekOnce()
    {
        var result = WeeklyStreakCalculator.Calculate(
            [
                new DateTimeOffset(2026, 6, 22, 8, 0, 0, TimeSpan.Zero),
                new DateTimeOffset(2026, 6, 24, 18, 0, 0, TimeSpan.Zero),
            ],
            WednesdayNow);

        Assert.Equal(1, result.CurrentStreakAtLastActiveWeek);
        Assert.Equal(1, result.BestStreak);
        Assert.Equal(new DateTimeOffset(2026, 6, 24, 18, 0, 0, TimeSpan.Zero), result.LastCompletedSessionAt);
    }

    [Fact]
    public void CalculateTracksCurrentAndBestAcrossConsecutiveWeeksAndGaps()
    {
        var result = WeeklyStreakCalculator.Calculate(
            [
                new DateTimeOffset(2026, 5, 25, 10, 0, 0, TimeSpan.Zero),
                new DateTimeOffset(2026, 6, 1, 10, 0, 0, TimeSpan.Zero),
                new DateTimeOffset(2026, 6, 8, 10, 0, 0, TimeSpan.Zero),
                new DateTimeOffset(2026, 6, 22, 10, 0, 0, TimeSpan.Zero),
            ],
            WednesdayNow);

        Assert.Equal(1, result.CurrentStreakAtLastActiveWeek);
        Assert.Equal(3, result.BestStreak);
    }

    [Fact]
    public void ToResponseZerosStaleCurrentAndPreservesBest()
    {
        var snapshot = new TraineeWeeklyStreak
        {
            TraineeUserId = "trainee-1",
            LastActiveWeekStart = new DateOnly(2026, 6, 1),
            CurrentStreakAtLastActiveWeek = 4,
            BestStreak = 7,
            LastCompletedSessionAt = new DateTimeOffset(2026, 6, 7, 18, 0, 0, TimeSpan.Zero),
            CalculatedAt = WednesdayNow,
        };

        var response = WeeklyStreakCalculator.ToResponse(snapshot, WednesdayNow);

        Assert.Equal(0, response.CurrentStreak);
        Assert.Equal(7, response.BestStreak);
        Assert.False(response.IsActiveThisWeek);
    }

    [Fact]
    public void WeekStartSeparatesLocalSundayAndMondayInWarsaw()
    {
        var sundayUtc = new DateTimeOffset(2026, 6, 21, 21, 59, 0, TimeSpan.Zero);
        var mondayUtc = new DateTimeOffset(2026, 6, 21, 22, 1, 0, TimeSpan.Zero);

        Assert.Equal(new DateOnly(2026, 6, 15), WeeklyStreakCalculator.GetWeekStart(sundayUtc));
        Assert.Equal(new DateOnly(2026, 6, 22), WeeklyStreakCalculator.GetWeekStart(mondayUtc));
    }

    [Fact]
    public void CalculateTreatsDecemberAndJanuaryWeeksAsConsecutive()
    {
        var result = WeeklyStreakCalculator.Calculate(
            [
                new DateTimeOffset(2025, 12, 28, 11, 0, 0, TimeSpan.Zero),
                new DateTimeOffset(2026, 1, 4, 11, 0, 0, TimeSpan.Zero),
            ],
            new DateTimeOffset(2026, 1, 4, 12, 0, 0, TimeSpan.Zero));

        Assert.Equal(2, result.CurrentStreakAtLastActiveWeek);
        Assert.Equal(2, result.BestStreak);
    }

    [Fact]
    public void ToResponseReturnsStableZeroContractWithoutSnapshot()
    {
        var response = WeeklyStreakCalculator.ToResponse(null, WednesdayNow);

        Assert.Equal(0, response.CurrentStreak);
        Assert.Equal(0, response.BestStreak);
        Assert.Null(response.LastActiveWeekStart);
        Assert.Null(response.LastCompletedWorkoutAt);
        Assert.False(response.IsActiveThisWeek);
    }
}
