using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using LiftMate.Api.Tests.Auth;

namespace LiftMate.Api.Tests.SharedSessions;

public sealed class SharedSessionEndpointTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task TrainerCanCreateSessionAndOnlyParticipantsCanReadIt()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var outsider = await AuthEndpointTests.Register(client, "trainer");

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var createResponse = await client.PostAsJsonAsync(
            "/shared-sessions",
            CreateRequest(trainee.User.Email));
        var created = await createResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();

        Assert.Equal(HttpStatusCode.Created, createResponse.StatusCode);
        Assert.NotNull(created);
        Assert.Equal(trainer.User.Id, created.TrainerUserId);
        Assert.Equal(trainee.User.Id, created.TraineeUserId);
        Assert.Equal(trainer.User.Email, created.TrainerEmail);
        Assert.Equal(trainee.User.Email, created.TraineeEmail);
        Assert.Equal("active", created.Status);
        Assert.Equal(1, created.Version);
        Assert.Single(created.Values);

        var trainerRead = await client.GetAsync($"/shared-sessions/{created.Id}");
        Assert.Equal(HttpStatusCode.OK, trainerRead.StatusCode);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var traineeRead = await client.GetAsync($"/shared-sessions/{created.Id}");
        Assert.Equal(HttpStatusCode.OK, traineeRead.StatusCode);

        client.DefaultRequestHeaders.Authorization = Bearer(outsider.AccessToken);
        var outsiderRead = await client.GetAsync($"/shared-sessions/{created.Id}");
        Assert.Equal(HttpStatusCode.Forbidden, outsiderRead.StatusCode);
    }

    [Fact]
    public async Task CreateRequiresTrainerAndTraineeParticipant()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var anotherTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var traineeCreate = await client.PostAsJsonAsync(
            "/shared-sessions",
            CreateRequest(trainee.User.Email));

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var trainerAsTrainee = await client.PostAsJsonAsync(
            "/shared-sessions",
            CreateRequest(anotherTrainer.User.Email));

        Assert.Equal(HttpStatusCode.Forbidden, traineeCreate.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, trainerAsTrainee.StatusCode);
    }

    [Fact]
    public async Task CreateRejectsSecondActiveSessionForSameTraineeButAllowsAfterClose()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var activeSession = await CreateSession(client, trainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var duplicateActive = await client.PostAsJsonAsync(
            "/shared-sessions",
            CreateRequest(trainee.User.Email));

        await client.PostAsync($"/shared-sessions/{activeSession.Id}/complete", null);
        var afterClose = await client.PostAsJsonAsync(
            "/shared-sessions",
            CreateRequest(trainee.User.Email));

        Assert.Equal(HttpStatusCode.Conflict, duplicateActive.StatusCode);
        Assert.Equal(HttpStatusCode.Created, afterClose.StatusCode);
    }

    [Fact]
    public async Task ParticipantsCanReadTheirActiveSession()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var outsider = await AuthEndpointTests.Register(client, "trainee");
        var session = await CreateSession(client, trainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var trainerActive = await client.GetAsync("/shared-sessions/active");
        Assert.Equal(HttpStatusCode.OK, trainerActive.StatusCode);
        var trainerSession = await trainerActive.Content.ReadFromJsonAsync<SharedSessionResponse>();

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var traineeActive = await client.GetAsync("/shared-sessions/active");
        Assert.Equal(HttpStatusCode.OK, traineeActive.StatusCode);
        var traineeSession = await traineeActive.Content.ReadFromJsonAsync<SharedSessionResponse>();

        client.DefaultRequestHeaders.Authorization = Bearer(outsider.AccessToken);
        var outsiderActive = await client.GetAsync("/shared-sessions/active");

        Assert.Equal(session.Id, trainerSession?.Id);
        Assert.Equal(session.Id, traineeSession?.Id);
        Assert.Equal(HttpStatusCode.NotFound, outsiderActive.StatusCode);
    }

    [Fact]
    public async Task TrainerAndTraineeCanUpdateActiveValueWithLastWriteWins()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var session = await CreateSession(client, trainer, trainee);
        var value = Assert.Single(session.Values);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var trainerUpdate = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/values/{value.Id}",
            new UpdateSharedSessionValueRequest(8, 42.5m, null));
        var afterTrainer = await trainerUpdate.Content.ReadFromJsonAsync<SharedSessionResponse>();

        Assert.Equal(HttpStatusCode.OK, trainerUpdate.StatusCode);
        Assert.NotNull(afterTrainer);
        Assert.Equal(2, afterTrainer.Version);
        Assert.Equal(trainer.User.Id, Assert.Single(afterTrainer.Values).UpdatedByUserId);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var traineeUpdate = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/values/{value.Id}",
            new UpdateSharedSessionValueRequest(10, 45m, null));
        var afterTrainee = await traineeUpdate.Content.ReadFromJsonAsync<SharedSessionResponse>();
        var finalValue = Assert.Single(afterTrainee?.Values ?? []);

        Assert.Equal(HttpStatusCode.OK, traineeUpdate.StatusCode);
        Assert.NotNull(afterTrainee);
        Assert.Equal(3, afterTrainee.Version);
        Assert.Equal(10, finalValue.Reps);
        Assert.Equal(45m, finalValue.Weight);
        Assert.Equal(trainee.User.Id, finalValue.UpdatedByUserId);
    }

    [Fact]
    public async Task InvalidValueUpdateReturnsBadRequestWithoutAdvancingVersion()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var session = await CreateSession(
            client,
            trainer,
            trainee,
            new CreateSharedSessionValueRequest("Plank", "time", 1, null, null, 60));
        var value = Assert.Single(session.Values);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var invalidUpdate = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/values/{value.Id}",
            new UpdateSharedSessionValueRequest(12, null, 45));

        Assert.Equal(HttpStatusCode.BadRequest, invalidUpdate.StatusCode);

        var readResponse = await client.GetAsync($"/shared-sessions/{session.Id}");
        var unchanged = await readResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();

        Assert.Equal(HttpStatusCode.OK, readResponse.StatusCode);
        Assert.NotNull(unchanged);
        Assert.Equal(1, unchanged.Version);
        Assert.Equal(60, Assert.Single(unchanged.Values).Seconds);
    }

    [Fact]
    public async Task CompleteAndCancelLifecycleIsTerminalAndIdempotent()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var completedSession = await CreateSession(client, trainer, trainee);
        var completedValue = Assert.Single(completedSession.Values);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var completeResponse = await client.PostAsync($"/shared-sessions/{completedSession.Id}/complete", null);
        var completed = await completeResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();
        var repeatedCompleteResponse = await client.PostAsync($"/shared-sessions/{completedSession.Id}/complete", null);
        var repeatedCompleted = await repeatedCompleteResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();
        var cancelCompletedResponse = await client.PostAsync($"/shared-sessions/{completedSession.Id}/cancel", null);
        var updateCompletedResponse = await client.PatchAsJsonAsync(
            $"/shared-sessions/{completedSession.Id}/values/{completedValue.Id}",
            new UpdateSharedSessionValueRequest(8, 40m, null));

        Assert.Equal(HttpStatusCode.OK, completeResponse.StatusCode);
        Assert.NotNull(completed);
        Assert.Equal("completed", completed.Status);
        Assert.Equal(2, completed.Version);
        Assert.Equal(HttpStatusCode.OK, repeatedCompleteResponse.StatusCode);
        Assert.NotNull(repeatedCompleted);
        Assert.Equal(2, repeatedCompleted.Version);
        Assert.Equal(HttpStatusCode.Conflict, cancelCompletedResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, updateCompletedResponse.StatusCode);

        var cancelledSession = await CreateSession(client, trainer, trainee);
        var cancelResponse = await client.PostAsync($"/shared-sessions/{cancelledSession.Id}/cancel", null);
        var cancelled = await cancelResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();
        var repeatedCancelResponse = await client.PostAsync($"/shared-sessions/{cancelledSession.Id}/cancel", null);
        var repeatedCancelled = await repeatedCancelResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();
        var completeCancelledResponse = await client.PostAsync($"/shared-sessions/{cancelledSession.Id}/complete", null);

        Assert.Equal(HttpStatusCode.OK, cancelResponse.StatusCode);
        Assert.NotNull(cancelled);
        Assert.Equal("cancelled", cancelled.Status);
        Assert.Equal(2, cancelled.Version);
        Assert.Equal(HttpStatusCode.OK, repeatedCancelResponse.StatusCode);
        Assert.NotNull(repeatedCancelled);
        Assert.Equal(2, repeatedCancelled.Version);
        Assert.Equal(HttpStatusCode.Conflict, completeCancelledResponse.StatusCode);
    }

    private static async Task<SharedSessionResponse> CreateSession(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer,
        AuthEndpointTests.AuthResponse trainee,
        CreateSharedSessionValueRequest? value = null)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/shared-sessions",
            CreateRequest(trainee.User.Email, value));
        var session = await response.Content.ReadFromJsonAsync<SharedSessionResponse>();

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(session);
        return session;
    }

    private static CreateSharedSessionRequest CreateRequest(
        string traineeEmail,
        CreateSharedSessionValueRequest? value = null)
    {
        return new CreateSharedSessionRequest(
            traineeEmail,
            [value ?? new CreateSharedSessionValueRequest("Bench press", "repsWeight", 1, 6, 40m, null)]);
    }

    private static AuthenticationHeaderValue Bearer(string accessToken)
    {
        return new AuthenticationHeaderValue("Bearer", accessToken);
    }

    private sealed record CreateSharedSessionRequest(
        string TraineeEmail,
        IReadOnlyList<CreateSharedSessionValueRequest> Values);

    private sealed record CreateSharedSessionValueRequest(
        string ExerciseName,
        string ExerciseType,
        int SetIndex,
        int? Reps,
        decimal? Weight,
        int? Seconds);

    private sealed record UpdateSharedSessionValueRequest(
        int? Reps,
        decimal? Weight,
        int? Seconds);

    private sealed record SharedSessionResponse(
        Guid Id,
        string TrainerUserId,
        string TraineeUserId,
        string TrainerEmail,
        string TraineeEmail,
        string Status,
        long Version,
        DateTimeOffset CreatedAt,
        DateTimeOffset UpdatedAt,
        DateTimeOffset? ClosedAt,
        IReadOnlyList<SharedSessionValueResponse> Values);

    private sealed record SharedSessionValueResponse(
        Guid Id,
        string ExerciseName,
        string ExerciseType,
        int SetIndex,
        int? Reps,
        decimal? Weight,
        int? Seconds,
        string? UpdatedByUserId,
        DateTimeOffset? UpdatedAt);
}
