using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using LiftMate.Api.WeeklyStreaks;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.Tests.WeeklyStreaks;

public sealed class WeeklyStreakServiceTests
{
    [Fact]
    public async Task RecalculateUsesCompletedSessionsAndCountsEachWeekOnce()
    {
        var now = new DateTimeOffset(2026, 6, 24, 10, 0, 0, TimeSpan.Zero);
        await using var fixture = await StreakFixture.Create(now);
        fixture.AddSession(SharedSessionStatus.Completed, new DateTimeOffset(2026, 6, 22, 9, 0, 0, TimeSpan.Zero), UserRole.Trainee);
        fixture.AddSession(SharedSessionStatus.Completed, new DateTimeOffset(2026, 6, 24, 9, 0, 0, TimeSpan.Zero), UserRole.Trainer);
        fixture.AddSession(SharedSessionStatus.Active, null, UserRole.Trainee);
        fixture.AddSession(SharedSessionStatus.Cancelled, new DateTimeOffset(2026, 6, 24, 9, 30, 0, TimeSpan.Zero), UserRole.Trainer);
        await fixture.DbContext.SaveChangesAsync();

        await fixture.Service.RecalculateForTraineeAsync(StreakFixture.TraineeId);
        await fixture.Service.RecalculateForTraineeAsync(StreakFixture.TraineeId);

        var snapshot = await fixture.DbContext.TraineeWeeklyStreaks.SingleAsync();
        Assert.Equal(new DateOnly(2026, 6, 22), snapshot.LastActiveWeekStart);
        Assert.Equal(1, snapshot.CurrentStreakAtLastActiveWeek);
        Assert.Equal(1, snapshot.BestStreak);
        Assert.Equal(new DateTimeOffset(2026, 6, 24, 9, 0, 0, TimeSpan.Zero), snapshot.LastCompletedSessionAt);
    }

    [Fact]
    public async Task ReadThroughCreatesMissingSnapshotAndReturnsZeroForNoHistory()
    {
        var now = new DateTimeOffset(2026, 6, 24, 10, 0, 0, TimeSpan.Zero);
        await using var fixture = await StreakFixture.Create(now, includeSecondTrainee: true);
        fixture.AddSession(SharedSessionStatus.Completed, now.AddHours(-1), UserRole.Trainee);
        await fixture.DbContext.SaveChangesAsync();

        var responses = await fixture.Service.GetResponsesForTraineesAsync(
            [StreakFixture.TraineeId, StreakFixture.SecondTraineeId]);

        Assert.Equal(1, responses[StreakFixture.TraineeId].CurrentStreak);
        Assert.Equal(0, responses[StreakFixture.SecondTraineeId].CurrentStreak);
        Assert.Single(await fixture.DbContext.TraineeWeeklyStreaks.ToListAsync());
    }

    [Fact]
    public async Task ResponseZerosCurrentAfterMissedWeekAndPreservesBest()
    {
        var now = new DateTimeOffset(2026, 6, 24, 10, 0, 0, TimeSpan.Zero);
        await using var fixture = await StreakFixture.Create(now);
        fixture.AddSession(SharedSessionStatus.Completed, new DateTimeOffset(2026, 5, 25, 10, 0, 0, TimeSpan.Zero), UserRole.Trainee);
        fixture.AddSession(SharedSessionStatus.Completed, new DateTimeOffset(2026, 6, 1, 10, 0, 0, TimeSpan.Zero), UserRole.Trainer);
        fixture.AddSession(SharedSessionStatus.Completed, new DateTimeOffset(2026, 6, 8, 10, 0, 0, TimeSpan.Zero), UserRole.Trainee);
        await fixture.DbContext.SaveChangesAsync();

        var response = await fixture.Service.GetResponseForTraineeAsync(StreakFixture.TraineeId);

        Assert.Equal(0, response.CurrentStreak);
        Assert.Equal(3, response.BestStreak);
        Assert.False(response.IsActiveThisWeek);
    }

    private sealed class StreakFixture : IAsyncDisposable
    {
        public const string TrainerId = "trainer-1";
        public const string TraineeId = "trainee-1";
        public const string SecondTraineeId = "trainee-2";

        private readonly SqliteConnection _connection;
        private readonly DateTimeOffset _now;

        private StreakFixture(
            SqliteConnection connection,
            ApplicationDbContext dbContext,
            WeeklyStreakService service,
            DateTimeOffset now)
        {
            _connection = connection;
            _now = now;
            DbContext = dbContext;
            Service = service;
        }

        public ApplicationDbContext DbContext { get; }

        public WeeklyStreakService Service { get; }

        public static async Task<StreakFixture> Create(
            DateTimeOffset now,
            bool includeSecondTrainee = false)
        {
            var connection = new SqliteConnection("DataSource=:memory:");
            await connection.OpenAsync();
            var options = new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseSqlite(connection)
                .Options;
            var dbContext = new ApplicationDbContext(options);
            await dbContext.Database.EnsureCreatedAsync();

            dbContext.Users.AddRange(
                User(TrainerId, UserRole.Trainer, null),
                User(TraineeId, UserRole.Trainee, TrainerId));
            if (includeSecondTrainee)
            {
                dbContext.Users.Add(User(SecondTraineeId, UserRole.Trainee, TrainerId));
            }

            await dbContext.SaveChangesAsync();
            var service = new WeeklyStreakService(dbContext, new FixedTimeProvider(now));
            return new StreakFixture(connection, dbContext, service, now);
        }

        public void AddSession(string status, DateTimeOffset? closedAt, string startedByRole)
        {
            DbContext.SharedSessions.Add(new SharedSession
            {
                Id = Guid.NewGuid(),
                TrainerUserId = TrainerId,
                TraineeUserId = TraineeId,
                StartedByUserId = startedByRole == UserRole.Trainer ? TrainerId : TraineeId,
                StartedByRole = startedByRole,
                Status = status,
                Version = 1,
                CreatedAt = closedAt?.AddHours(-1) ?? ServiceTime,
                UpdatedAt = closedAt ?? ServiceTime,
                ClosedAt = closedAt,
            });
        }

        private DateTimeOffset ServiceTime => _now;

        public async ValueTask DisposeAsync()
        {
            await DbContext.DisposeAsync();
            await _connection.DisposeAsync();
        }

        private static ApplicationUser User(string id, string role, string? trainerId)
        {
            return new ApplicationUser
            {
                Id = id,
                UserName = $"{id}@example.test",
                NormalizedUserName = $"{id.ToUpperInvariant()}@EXAMPLE.TEST",
                Email = $"{id}@example.test",
                NormalizedEmail = $"{id.ToUpperInvariant()}@EXAMPLE.TEST",
                DisplayName = id,
                LiftMateRole = role,
                TrainerUserId = trainerId,
            };
        }
    }

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
