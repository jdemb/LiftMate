using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using LiftMate.Api.Tests.Auth;
using LiftMate.Api.WorkoutSets;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LiftMate.Api.Tests.SharedSessions;

public sealed class PostWorkoutFeedbackEndpointTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task TraineeCreatesFeedbackForCompletedTrainerLedAndSelfStartedSessions()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var trainerLed = await SeedSession(trainer.User.Id, trainee.User.Id, UserRole.Trainer, SharedSessionStatus.Completed);
        var selfStarted = await SeedSession(trainer.User.Id, trainee.User.Id, UserRole.Trainee, SharedSessionStatus.Completed);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var trainerLedResponse = await client.PostAsJsonAsync(
            $"/shared-sessions/{trainerLed}/feedback",
            new FeedbackRequest(4, "  Solidny trening  "));
        Assert.Equal(HttpStatusCode.Created, trainerLedResponse.StatusCode);
        var trainerLedBody = await trainerLedResponse.Content.ReadFromJsonAsync<FeedbackResponse>();
        var selfStartedResponse = await client.PostAsJsonAsync(
            $"/shared-sessions/{selfStarted}/feedback",
            new FeedbackRequest(5, null));
        Assert.Equal(HttpStatusCode.Created, selfStartedResponse.StatusCode);
        var selfStartedBody = await selfStartedResponse.Content.ReadFromJsonAsync<FeedbackResponse>();

        Assert.NotNull(trainerLedBody);
        Assert.Equal(trainerLed, trainerLedBody.SharedSessionId);
        Assert.Equal(4, trainerLedBody.WellbeingRating);
        Assert.Equal("Solidny trening", trainerLedBody.Comment);
        Assert.NotEqual(default, trainerLedBody.SubmittedAt);
        Assert.NotNull(selfStartedBody);
        Assert.Equal(selfStarted, selfStartedBody.SharedSessionId);
        Assert.Equal(5, selfStartedBody.WellbeingRating);
        Assert.Null(selfStartedBody.Comment);
    }

    [Fact]
    public async Task SelfStartedSessionCompletesThenFeedbackAppearsInTraineeAndTrainerHistory()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Feedback journey");
        await AssignWorkoutSet(client, trainer, workoutSet.Id, trainee.User.Id);
        var session = await StartFromWorkoutSet(client, trainee, workoutSet.Id);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var completeResponse = await client.PostAsync(
            $"/shared-sessions/{session.Id}/complete",
            null);
        var feedbackResponse = await client.PostAsJsonAsync(
            $"/shared-sessions/{session.Id}/feedback",
            new FeedbackRequest(4, "Po pełnym przepływie"));
        var traineeHistoryResponse = await client.GetAsync(
            $"/training-history/sessions/{session.Id}");
        var traineeHistory = await traineeHistoryResponse.Content
            .ReadFromJsonAsync<HistorySessionResponse>();

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var trainerHistoryResponse = await client.GetAsync(
            $"/training-history/sessions/{session.Id}");
        var trainerHistory = await trainerHistoryResponse.Content
            .ReadFromJsonAsync<HistorySessionResponse>();

        Assert.Equal(HttpStatusCode.OK, completeResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Created, feedbackResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, traineeHistoryResponse.StatusCode);
        Assert.Equal(4, traineeHistory?.Feedback?.WellbeingRating);
        Assert.Equal("Po pełnym przepływie", traineeHistory?.Feedback?.Comment);
        Assert.Equal(HttpStatusCode.OK, trainerHistoryResponse.StatusCode);
        Assert.Equal(4, trainerHistory?.Feedback?.WellbeingRating);
        Assert.Equal("Po pełnym przepływie", trainerHistory?.Feedback?.Comment);
    }

    [Fact]
    public async Task IdenticalReplayReturnsExistingFeedbackButDifferentReplayConflicts()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var sessionId = await SeedSession(trainer.User.Id, trainee.User.Id, UserRole.Trainee, SharedSessionStatus.Completed);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var first = await client.PostAsJsonAsync(
            $"/shared-sessions/{sessionId}/feedback",
            new FeedbackRequest(3, "  OK  "));
        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        var created = await first.Content.ReadFromJsonAsync<FeedbackResponse>();
        var replay = await client.PostAsJsonAsync(
            $"/shared-sessions/{sessionId}/feedback",
            new FeedbackRequest(3, "OK"));
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        var replayed = await replay.Content.ReadFromJsonAsync<FeedbackResponse>();
        var changed = await client.PostAsJsonAsync(
            $"/shared-sessions/{sessionId}/feedback",
            new FeedbackRequest(4, "OK"));

        Assert.NotNull(created);
        Assert.NotNull(replayed);
        Assert.Equal(created.SubmittedAt, replayed.SubmittedAt);
        Assert.Equal(created.Comment, replayed.Comment);
        Assert.Equal(HttpStatusCode.Conflict, changed.StatusCode);
    }

    [Fact]
    public async Task FeedbackRejectsInvalidActorsInvalidStatesAndInvalidPayloads()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var otherTrainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var completed = await SeedSession(trainer.User.Id, trainee.User.Id, UserRole.Trainee, SharedSessionStatus.Completed);
        var active = await SeedSession(trainer.User.Id, trainee.User.Id, UserRole.Trainee, SharedSessionStatus.Active);
        var cancelled = await SeedSession(trainer.User.Id, trainee.User.Id, UserRole.Trainee, SharedSessionStatus.Cancelled);

        client.DefaultRequestHeaders.Authorization = null;
        var anonymous = await client.PostAsJsonAsync(
            $"/shared-sessions/{completed}/feedback",
            new FeedbackRequest(4, null));

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var trainerAttempt = await client.PostAsJsonAsync(
            $"/shared-sessions/{completed}/feedback",
            new FeedbackRequest(4, null));

        client.DefaultRequestHeaders.Authorization = Bearer(otherTrainee.AccessToken);
        var otherTraineeAttempt = await client.PostAsJsonAsync(
            $"/shared-sessions/{completed}/feedback",
            new FeedbackRequest(4, null));

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var activeAttempt = await client.PostAsJsonAsync(
            $"/shared-sessions/{active}/feedback",
            new FeedbackRequest(4, null));
        var cancelledAttempt = await client.PostAsJsonAsync(
            $"/shared-sessions/{cancelled}/feedback",
            new FeedbackRequest(4, null));
        var missingAttempt = await client.PostAsJsonAsync(
            $"/shared-sessions/{Guid.NewGuid()}/feedback",
            new FeedbackRequest(4, null));
        var tooLow = await client.PostAsJsonAsync(
            $"/shared-sessions/{completed}/feedback",
            new FeedbackRequest(0, null));
        var tooHigh = await client.PostAsJsonAsync(
            $"/shared-sessions/{completed}/feedback",
            new FeedbackRequest(6, null));
        var tooLong = await client.PostAsJsonAsync(
            $"/shared-sessions/{completed}/feedback",
            new FeedbackRequest(4, new string('x', 1001)));

        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, trainerAttempt.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, otherTraineeAttempt.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, activeAttempt.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, cancelledAttempt.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, missingAttempt.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, tooLow.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, tooHigh.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, tooLong.StatusCode);
    }

    [Fact]
    public async Task HistoryDetailReturnsFeedbackForTraineeAndCurrentTrainerAndNullForOldSessions()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var withFeedback = await SeedSession(trainer.User.Id, trainee.User.Id, UserRole.Trainee, SharedSessionStatus.Completed);
        var withoutFeedback = await SeedSession(trainer.User.Id, trainee.User.Id, UserRole.Trainee, SharedSessionStatus.Completed);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var feedbackResponse = await client.PostAsJsonAsync(
            $"/shared-sessions/{withFeedback}/feedback",
            new FeedbackRequest(2, ""));
        Assert.Equal(HttpStatusCode.Created, feedbackResponse.StatusCode);

        var traineeDetailResponse = await client.GetAsync($"/training-history/sessions/{withFeedback}");
        var traineeDetail = await traineeDetailResponse.Content.ReadFromJsonAsync<HistorySessionResponse>();
        var withoutFeedbackResponse = await client.GetAsync($"/training-history/sessions/{withoutFeedback}");
        var withoutFeedbackDetail = await withoutFeedbackResponse.Content.ReadFromJsonAsync<HistorySessionResponse>();

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var trainerDetailResponse = await client.GetAsync($"/training-history/sessions/{withFeedback}");
        var trainerDetail = await trainerDetailResponse.Content.ReadFromJsonAsync<HistorySessionResponse>();

        Assert.Equal(HttpStatusCode.OK, traineeDetailResponse.StatusCode);
        Assert.NotNull(traineeDetail?.Feedback);
        Assert.Equal(2, traineeDetail.Feedback.WellbeingRating);
        Assert.Null(traineeDetail.Feedback.Comment);
        Assert.NotEqual(default, traineeDetail.Feedback.SubmittedAt);
        Assert.Equal(HttpStatusCode.OK, withoutFeedbackResponse.StatusCode);
        Assert.Null(withoutFeedbackDetail?.Feedback);
        Assert.Equal(HttpStatusCode.OK, trainerDetailResponse.StatusCode);
        Assert.NotNull(trainerDetail?.Feedback);
        Assert.Equal(2, trainerDetail.Feedback.WellbeingRating);
    }

    [Fact]
    public async Task ParallelFeedbackRequestsCreateExactlyOneImmutableRecord()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var sessionId = await SeedSession(trainer.User.Id, trainee.User.Id, UserRole.Trainee, SharedSessionStatus.Completed);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var first = client.PostAsJsonAsync(
            $"/shared-sessions/{sessionId}/feedback",
            new FeedbackRequest(5, "Pierwszy"));
        var second = client.PostAsJsonAsync(
            $"/shared-sessions/{sessionId}/feedback",
            new FeedbackRequest(5, "Pierwszy"));
        var responses = await Task.WhenAll(first, second);

        Assert.All(responses, response => Assert.True(
            response.StatusCode is HttpStatusCode.Created or HttpStatusCode.OK,
            $"Unexpected status: {response.StatusCode}"));

        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var count = await dbContext.Database
            .SqlQueryRaw<int>(
                "SELECT COUNT(*) AS Value FROM PostWorkoutFeedbacks WHERE SharedSessionId = {0}",
                sessionId)
            .SingleAsync();
        Assert.Equal(1, count);
    }

    private async Task<Guid> SeedSession(
        string trainerUserId,
        string traineeUserId,
        string startedByRole,
        string status)
    {
        var now = DateTimeOffset.UtcNow;
        var session = new SharedSession
        {
            Id = Guid.NewGuid(),
            TrainerUserId = trainerUserId,
            TraineeUserId = traineeUserId,
            StartedByUserId = startedByRole == UserRole.Trainee ? traineeUserId : trainerUserId,
            StartedByRole = startedByRole,
            WorkoutSetName = "Feedback test",
            Status = status,
            Version = status == SharedSessionStatus.Active ? 1 : 2,
            CreatedAt = now.AddMinutes(-45),
            UpdatedAt = now,
            ClosedAt = status == SharedSessionStatus.Active ? null : now,
        };
        session.Values.Add(new SharedSessionValue
        {
            Id = Guid.NewGuid(),
            ExerciseId = Guid.NewGuid(),
            WorkoutSetRowId = Guid.NewGuid(),
            ExerciseName = "Bench press",
            ExerciseType = ExerciseValueType.RepsWeight,
            ExerciseOrder = 1,
            SetIndex = 1,
            Reps = 8,
            Weight = 40m,
            IsDone = true,
            CompletedAt = status == SharedSessionStatus.Completed ? now : null,
        });

        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        dbContext.SharedSessions.Add(session);
        await dbContext.SaveChangesAsync();
        return session.Id;
    }

    private static async Task<WorkoutSetResponse> CreateWorkoutSet(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer,
        string name)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/workout-sets",
            new CreateWorkoutSetRequest(
                name,
                [new WorkoutSetRowRequest(1, 1, "Bench press", "repsWeight", 8, 40m, null)]));
        var body = await response.Content.ReadAsStringAsync();

        Assert.True(response.StatusCode == HttpStatusCode.Created, body);
        var workoutSet = await response.Content.ReadFromJsonAsync<WorkoutSetResponse>();
        Assert.NotNull(workoutSet);
        return workoutSet;
    }

    private static async Task AssignWorkoutSet(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer,
        Guid workoutSetId,
        string traineeUserId)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.PostAsJsonAsync(
            $"/workout-sets/{workoutSetId}/assignments",
            new AssignWorkoutSetRequest([traineeUserId]));
        var body = await response.Content.ReadAsStringAsync();

        Assert.True(response.StatusCode == HttpStatusCode.OK, body);
    }

    private static async Task<SharedSessionStartResponse> StartFromWorkoutSet(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainee,
        Guid workoutSetId)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/shared-sessions/from-workout-set",
            new StartSharedSessionFromWorkoutSetRequest(workoutSetId, null));
        var body = await response.Content.ReadAsStringAsync();

        Assert.True(response.StatusCode == HttpStatusCode.Created, body);
        var session = await response.Content.ReadFromJsonAsync<SharedSessionStartResponse>();
        Assert.NotNull(session);
        return session;
    }

    private static AuthenticationHeaderValue Bearer(string accessToken)
    {
        return new AuthenticationHeaderValue("Bearer", accessToken);
    }

    private sealed record FeedbackRequest(int WellbeingRating, string? Comment);

    private sealed record CreateWorkoutSetRequest(
        string Name,
        IReadOnlyList<WorkoutSetRowRequest> Rows);

    private sealed record WorkoutSetRowRequest(
        int ExerciseOrder,
        int SetIndex,
        string ExerciseName,
        string ExerciseType,
        int? Reps,
        decimal? Weight,
        int? Seconds);

    private sealed record AssignWorkoutSetRequest(IReadOnlyList<string> TraineeUserIds);

    private sealed record StartSharedSessionFromWorkoutSetRequest(
        Guid WorkoutSetId,
        string? TraineeUserId);

    private sealed record WorkoutSetResponse(Guid Id);

    private sealed record SharedSessionStartResponse(Guid Id);

    private sealed record FeedbackResponse(
        Guid SharedSessionId,
        int WellbeingRating,
        string? Comment,
        DateTimeOffset SubmittedAt);

    private sealed record HistorySessionResponse(
        Guid Id,
        string WorkoutSetName,
        DateTimeOffset StartedAt,
        DateTimeOffset CompletedAt,
        int DurationSeconds,
        int ExerciseCount,
        int SeriesCount,
        HistoryFeedbackResponse? Feedback,
        IReadOnlyList<HistoryExerciseResponse> Exercises);

    private sealed record HistoryFeedbackResponse(
        int WellbeingRating,
        string? Comment,
        DateTimeOffset SubmittedAt);

    private sealed record HistoryExerciseResponse(
        Guid? ExerciseId,
        decimal MaximumValue,
        IReadOnlyList<HistorySeriesResponse> Series);

    private sealed record HistorySeriesResponse(
        int SetIndex,
        int? Reps,
        decimal? Weight,
        int? Seconds);
}
