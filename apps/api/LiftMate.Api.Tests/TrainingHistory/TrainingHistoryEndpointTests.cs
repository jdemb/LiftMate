using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using LiftMate.Api.Tests.Auth;
using Microsoft.Extensions.DependencyInjection;

namespace LiftMate.Api.Tests.TrainingHistory;

public sealed class TrainingHistoryEndpointTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task ListReturnsOnlyCompletedSessionsInStablePagesOfTwenty()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var exerciseId = Guid.NewGuid();
        await SeedSessions(
            trainer.User.Id,
            trainee.User.Id,
            exerciseId,
            completedCount: 23,
            sameCompletionTime: true);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var firstResponse = await client.GetAsync("/training-history/sessions");
        var first = await firstResponse.Content.ReadFromJsonAsync<HistoryPageResponse>();
        var secondResponse = await client.GetAsync(
            $"/training-history/sessions?cursor={Uri.EscapeDataString(first!.NextCursor!)}");
        var second = await secondResponse.Content.ReadFromJsonAsync<HistoryPageResponse>();
        var malformed = await client.GetAsync("/training-history/sessions?cursor=not-a-cursor");

        Assert.Equal(HttpStatusCode.OK, firstResponse.StatusCode);
        Assert.Equal(20, first.Items.Count);
        Assert.NotNull(first.NextCursor);
        Assert.Equal(HttpStatusCode.OK, secondResponse.StatusCode);
        Assert.Equal(3, second?.Items.Count);
        Assert.Null(second?.NextCursor);
        Assert.Empty(first.Items.Select(item => item.Id).Intersect(second!.Items.Select(item => item.Id)));
        Assert.All(first.Items.Concat(second.Items), item =>
        {
            Assert.Equal(1, item.ExerciseCount);
            Assert.Equal(2, item.SeriesCount);
            Assert.Equal(600, item.DurationSeconds);
        });
        Assert.Equal(HttpStatusCode.BadRequest, malformed.StatusCode);
    }

    [Fact]
    public async Task DetailAndProgressReturnOrderedMaximumValuesAndDeltas()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var exerciseId = Guid.NewGuid();
        var sessionIds = await SeedSessions(
            trainer.User.Id,
            trainee.User.Id,
            exerciseId,
            completedCount: 3,
            weightStart: 40m);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var detailResponse = await client.GetAsync($"/training-history/sessions/{sessionIds[0]}");
        var detail = await detailResponse.Content.ReadFromJsonAsync<HistorySessionResponse>();
        var progressResponse = await client.GetAsync($"/training-history/exercises/{exerciseId}");
        var progress = await progressResponse.Content.ReadFromJsonAsync<ExerciseProgressResponse>();

        Assert.Equal(HttpStatusCode.OK, detailResponse.StatusCode);
        Assert.NotNull(detail);
        var exercise = Assert.Single(detail.Exercises);
        Assert.Equal(exerciseId, exercise.ExerciseId);
        Assert.Equal(40m, exercise.MaximumValue);
        Assert.Equal([1, 2], exercise.Series.Select(series => series.SetIndex));

        Assert.Equal(HttpStatusCode.OK, progressResponse.StatusCode);
        Assert.NotNull(progress);
        Assert.Equal(3, progress.Points.Count);
        Assert.Equal(40m, progress.StartValue);
        Assert.Equal(50m, progress.CurrentValue);
        Assert.Equal(10m, progress.OverallDelta);
        Assert.Null(progress.Points[0].Delta);
        Assert.Equal(5m, progress.Points[1].Delta);
        Assert.Equal(5m, progress.Points[2].Delta);
    }

    [Fact]
    public async Task DetailDurationUsesSessionStartAndCompletionTimestamps()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var completedAt = DateTimeOffset.UtcNow;
        var session = CreateSession(
            trainer.User.Id,
            trainee.User.Id,
            Guid.NewGuid(),
            SharedSessionStatus.Completed,
            completedAt,
            40m,
            duration: TimeSpan.FromSeconds(42));

        await using (var scope = factory.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            dbContext.SharedSessions.Add(session);
            await dbContext.SaveChangesAsync();
        }

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var response = await client.GetAsync(
            $"/training-history/sessions/{session.Id}");
        var detail = await response.Content.ReadFromJsonAsync<HistorySessionResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(detail);
        Assert.Equal(42, detail.DurationSeconds);
        Assert.Equal(
            TimeSpan.FromSeconds(42),
            detail.CompletedAt - detail.StartedAt);
    }

    [Fact]
    public async Task CurrentTrainerCanReadButFormerAndUnrelatedTrainersCannot()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var newTrainer = await AuthEndpointTests.Register(client, "trainer");
        var outsider = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var exerciseId = Guid.NewGuid();
        var sessionId = (await SeedSessions(
            trainer.User.Id,
            trainee.User.Id,
            exerciseId,
            completedCount: 1))[0];

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var currentList = await client.GetAsync(
            $"/training-history/sessions?traineeUserId={trainee.User.Id}");
        var currentDetail = await client.GetAsync($"/training-history/sessions/{sessionId}");
        var currentProgress = await client.GetAsync(
            $"/training-history/exercises/{exerciseId}?traineeUserId={trainee.User.Id}");

        client.DefaultRequestHeaders.Authorization = Bearer(outsider.AccessToken);
        var outsiderList = await client.GetAsync(
            $"/training-history/sessions?traineeUserId={trainee.User.Id}");

        await PairingEndpointTests.PairTrainerAndTrainee(client, newTrainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var formerList = await client.GetAsync(
            $"/training-history/sessions?traineeUserId={trainee.User.Id}");
        var formerDetail = await client.GetAsync($"/training-history/sessions/{sessionId}");
        var formerProgress = await client.GetAsync(
            $"/training-history/exercises/{exerciseId}?traineeUserId={trainee.User.Id}");

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var traineeList = await client.GetAsync("/training-history/sessions");

        Assert.Equal(HttpStatusCode.OK, currentList.StatusCode);
        Assert.Equal(HttpStatusCode.OK, currentDetail.StatusCode);
        Assert.Equal(HttpStatusCode.OK, currentProgress.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, outsiderList.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, formerList.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, formerDetail.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, formerProgress.StatusCode);
        Assert.Equal(HttpStatusCode.OK, traineeList.StatusCode);
    }

    [Fact]
    public async Task ProgressSelectsTypeSpecificMaximumsForAllExerciseTypes()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var weightId = Guid.NewGuid();
        var repsId = Guid.NewGuid();
        var timeId = Guid.NewGuid();

        await using (var scope = factory.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            for (var index = 0; index < 2; index++)
            {
                var completedAt = DateTimeOffset.UtcNow.AddDays(index - 2);
                var session = new SharedSession
                {
                    Id = Guid.NewGuid(),
                    TrainerUserId = trainer.User.Id,
                    TraineeUserId = trainee.User.Id,
                    StartedByUserId = trainee.User.Id,
                    StartedByRole = "trainee",
                    WorkoutSetName = "Mixed",
                    Status = SharedSessionStatus.Completed,
                    Version = 2,
                    CreatedAt = completedAt.AddMinutes(-10),
                    UpdatedAt = completedAt,
                    ClosedAt = completedAt,
                };
                session.Values.Add(CreateTypedValue(weightId, 1, ExerciseValueType.RepsWeight, 8, 40m + index * 5m, null));
                session.Values.Add(CreateTypedValue(weightId, 2, ExerciseValueType.RepsWeight, 8, 42.5m + index * 5m, null));
                session.Values.Add(CreateTypedValue(repsId, 1, ExerciseValueType.RepsOnly, 8 + index * 2, null, null));
                session.Values.Add(CreateTypedValue(repsId, 2, ExerciseValueType.RepsOnly, 10 + index * 2, null, null));
                session.Values.Add(CreateTypedValue(timeId, 1, ExerciseValueType.Time, null, null, 30 + index * 15));
                session.Values.Add(CreateTypedValue(timeId, 2, ExerciseValueType.Time, null, null, 40 + index * 15));
                dbContext.SharedSessions.Add(session);
            }
            await dbContext.SaveChangesAsync();
        }

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var weight = await ReadProgress(client, weightId);
        var reps = await ReadProgress(client, repsId);
        var time = await ReadProgress(client, timeId);

        Assert.Equal("kg", weight.Unit);
        Assert.Equal(47.5m, weight.CurrentValue);
        Assert.Equal(5m, weight.OverallDelta);
        Assert.Equal("powt.", reps.Unit);
        Assert.Equal(12m, reps.CurrentValue);
        Assert.Equal(2m, reps.OverallDelta);
        Assert.Equal("s", time.Unit);
        Assert.Equal(55m, time.CurrentValue);
        Assert.Equal(15m, time.OverallDelta);
    }

    private async Task<IReadOnlyList<Guid>> SeedSessions(
        string trainerUserId,
        string traineeUserId,
        Guid exerciseId,
        int completedCount,
        decimal weightStart = 40m,
        bool sameCompletionTime = false)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var ids = new List<Guid>();
        var baseTime = DateTimeOffset.UtcNow.AddDays(-completedCount);

        for (var index = 0; index < completedCount; index++)
        {
            var completedAt = sameCompletionTime ? baseTime : baseTime.AddDays(index);
            var session = CreateSession(
                trainerUserId,
                traineeUserId,
                exerciseId,
                SharedSessionStatus.Completed,
                completedAt,
                weightStart + (index * 5m));
            ids.Add(session.Id);
            dbContext.SharedSessions.Add(session);
        }

        dbContext.SharedSessions.Add(CreateSession(
            trainerUserId,
            traineeUserId,
            exerciseId,
            SharedSessionStatus.Cancelled,
            baseTime.AddDays(-1),
            100m));
        dbContext.SharedSessions.Add(CreateSession(
            trainerUserId,
            traineeUserId,
            exerciseId,
            SharedSessionStatus.Active,
            null,
            100m));
        await dbContext.SaveChangesAsync();
        return ids;
    }

    private static SharedSession CreateSession(
        string trainerUserId,
        string traineeUserId,
        Guid exerciseId,
        string status,
        DateTimeOffset? completedAt,
        decimal maximumWeight,
        TimeSpan? duration = null)
    {
        var createdAt = completedAt.HasValue
            ? completedAt.Value - (duration ?? TimeSpan.FromMinutes(10))
            : DateTimeOffset.UtcNow;
        var session = new SharedSession
        {
            Id = Guid.NewGuid(),
            TrainerUserId = trainerUserId,
            TraineeUserId = traineeUserId,
            StartedByUserId = traineeUserId,
            StartedByRole = "trainee",
            WorkoutSetName = "Plan A",
            Status = status,
            Version = 2,
            CreatedAt = createdAt,
            UpdatedAt = completedAt ?? createdAt,
            ClosedAt = completedAt,
        };
        session.Values.Add(CreateValue(exerciseId, 1, maximumWeight - 2.5m));
        session.Values.Add(CreateValue(exerciseId, 2, maximumWeight));
        return session;
    }

    private static SharedSessionValue CreateValue(Guid exerciseId, int setIndex, decimal weight)
    {
        return new SharedSessionValue
        {
            Id = Guid.NewGuid(),
            ExerciseId = exerciseId,
            WorkoutSetRowId = Guid.NewGuid(),
            ExerciseName = "Bench press",
            ExerciseType = ExerciseValueType.RepsWeight,
            ExerciseOrder = 1,
            SetIndex = setIndex,
            Reps = 8,
            Weight = weight,
        };
    }

    private static SharedSessionValue CreateTypedValue(
        Guid exerciseId,
        int setIndex,
        string exerciseType,
        int? reps,
        decimal? weight,
        int? seconds)
    {
        return new SharedSessionValue
        {
            Id = Guid.NewGuid(),
            ExerciseId = exerciseId,
            WorkoutSetRowId = Guid.NewGuid(),
            ExerciseName = exerciseType,
            ExerciseType = exerciseType,
            ExerciseOrder = exerciseType switch
            {
                ExerciseValueType.RepsWeight => 1,
                ExerciseValueType.RepsOnly => 2,
                _ => 3,
            },
            SetIndex = setIndex,
            Reps = reps,
            Weight = weight,
            Seconds = seconds,
        };
    }

    private static async Task<ExerciseProgressResponse> ReadProgress(
        HttpClient client,
        Guid exerciseId)
    {
        var response = await client.GetAsync($"/training-history/exercises/{exerciseId}");
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.StatusCode == HttpStatusCode.OK, body);
        return (await response.Content.ReadFromJsonAsync<ExerciseProgressResponse>())!;
    }

    private static AuthenticationHeaderValue Bearer(string accessToken)
    {
        return new AuthenticationHeaderValue("Bearer", accessToken);
    }

    private sealed record HistoryPageResponse(
        IReadOnlyList<HistorySummaryResponse> Items,
        string? NextCursor);

    private sealed record HistorySummaryResponse(
        Guid Id,
        string WorkoutSetName,
        DateTimeOffset StartedAt,
        DateTimeOffset CompletedAt,
        int DurationSeconds,
        int ExerciseCount,
        int SeriesCount);

    private sealed record HistorySessionResponse(
        Guid Id,
        string WorkoutSetName,
        DateTimeOffset StartedAt,
        DateTimeOffset CompletedAt,
        int DurationSeconds,
        int ExerciseCount,
        int SeriesCount,
        IReadOnlyList<HistoryExerciseResponse> Exercises);

    private sealed record HistoryExerciseResponse(
        Guid? ExerciseId,
        decimal MaximumValue,
        IReadOnlyList<HistorySeriesResponse> Series);

    private sealed record HistorySeriesResponse(
        int SetIndex,
        int? Reps,
        decimal? Weight,
        int? Seconds);

    private sealed record ExerciseProgressResponse(
        Guid ExerciseId,
        string ExerciseName,
        string ExerciseType,
        string Unit,
        decimal StartValue,
        decimal CurrentValue,
        decimal OverallDelta,
        IReadOnlyList<ExerciseProgressPointResponse> Points);

    private sealed record ExerciseProgressPointResponse(
        Guid SessionId,
        DateTimeOffset CompletedAt,
        decimal Value,
        decimal? Delta);
}
