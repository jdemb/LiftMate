using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.SignalR.Client;
using LiftMate.Api.Tests.Auth;

namespace LiftMate.Api.Tests.SharedSessions;

public sealed class SharedSessionHubTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task AlreadyConnectedTraineeReceivesSessionStartedWhenTrainerCreatesSession()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var receivedStart = new TaskCompletionSource<SharedSessionResponse>(
            TaskCreationOptions.RunContinuationsAsynchronously);

        await using var connection = CreateConnection(trainee.AccessToken);
        connection.On<SharedSessionResponse>("sessionStarted", response =>
        {
            receivedStart.TrySetResult(response);
        });

        await connection.StartAsync();

        var session = await CreateSession(client, trainer, trainee);
        var started = await receivedStart.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.Equal(session.Id, started.Id);
        Assert.Equal(trainer.User.Id, started.TrainerUserId);
        Assert.Equal(trainee.User.Id, started.TraineeUserId);
        Assert.Equal("active", started.Status);
    }

    [Fact]
    public async Task AlreadyConnectedTrainerReceivesSessionStartedWhenTraineeSelfStarts()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Solo day");
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var receivedStart = new TaskCompletionSource<SharedSessionResponse>(
            TaskCreationOptions.RunContinuationsAsynchronously);

        await using var connection = CreateConnection(trainer.AccessToken);
        connection.On<SharedSessionResponse>("sessionStarted", response =>
        {
            receivedStart.TrySetResult(response);
        });

        await connection.StartAsync();

        var session = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        var started = await receivedStart.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.Equal(session.Id, started.Id);
        Assert.Equal(workoutSet.Id, started.WorkoutSetId);
        Assert.Equal(trainer.User.Id, started.TrainerUserId);
        Assert.Equal(trainee.User.Id, started.TraineeUserId);
        Assert.Equal(trainee.User.Id, started.StartedByUserId);
        Assert.Equal("trainee", started.StartedByRole);
    }

    [Fact]
    public async Task ParticipantCanJoinWithQueryStringTokenAndReceiveUpdateBroadcast()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var session = await CreateSession(client, trainer, trainee);
        var value = Assert.Single(session.Values);
        var receivedUpdate = new TaskCompletionSource<SharedSessionResponse>(
            TaskCreationOptions.RunContinuationsAsynchronously);

        await using var connection = CreateConnection(trainee.AccessToken);
        connection.On<SharedSessionResponse>("sessionUpdated", response =>
        {
            receivedUpdate.TrySetResult(response);
        });

        await connection.StartAsync();
        await connection.InvokeAsync("JoinSession", session.Id);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var updateResponse = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/values/{value.Id}",
            new UpdateSharedSessionValueRequest(8, 42.5m, null));
        var broadcast = await receivedUpdate.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);
        Assert.Equal(session.Id, broadcast.Id);
        Assert.Equal(2, broadcast.Version);
        Assert.Equal(8, Assert.Single(broadcast.Values).Reps);
    }

    [Fact]
    public async Task NonParticipantCannotJoinSessionGroup()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var outsider = await AuthEndpointTests.Register(client, "trainer");
        var session = await CreateSession(client, trainer, trainee);

        await using var connection = CreateConnection(outsider.AccessToken);

        await connection.StartAsync();
        await Assert.ThrowsAsync<HubException>(() => connection.InvokeAsync("JoinSession", session.Id));
    }

    private HubConnection CreateConnection(string accessToken)
    {
        var hubUri = new Uri(
            factory.Server.BaseAddress,
            $"/hubs/shared-sessions?access_token={Uri.EscapeDataString(accessToken)}");

        return new HubConnectionBuilder()
            .WithUrl(hubUri, options =>
            {
                options.HttpMessageHandlerFactory = _ => factory.Server.CreateHandler();
                options.Transports = HttpTransportType.LongPolling;
            })
            .Build();
    }

    private static async Task<SharedSessionResponse> CreateSession(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer,
        AuthEndpointTests.AuthResponse trainee)
    {
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/shared-sessions",
            new CreateSharedSessionRequest(
                trainee.User.Email,
                [new CreateSharedSessionValueRequest("Bench press", "repsWeight", 1, 6, 40m, null)]));
        var session = await response.Content.ReadFromJsonAsync<SharedSessionResponse>();

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(session);
        return session;
    }

    private static async Task<WorkoutSetDetailResponse> CreateWorkoutSet(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer,
        string name)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/workout-sets",
            new CreateWorkoutSetRequest(
                name,
                [new WorkoutSetRowRequest(1, 1, "Bench press", "repsWeight", 6, 40m, null)]));
        var body = await response.Content.ReadAsStringAsync();

        Assert.True(response.StatusCode == HttpStatusCode.Created, body);

        var workoutSet = await response.Content.ReadFromJsonAsync<WorkoutSetDetailResponse>();

        Assert.NotNull(workoutSet);
        return workoutSet;
    }

    private static async Task AssignWorkoutSet(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer,
        Guid workoutSetId,
        IReadOnlyList<string> traineeUserIds)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.PostAsJsonAsync(
            $"/workout-sets/{workoutSetId}/assignments",
            new AssignWorkoutSetRequest(traineeUserIds));
        var body = await response.Content.ReadAsStringAsync();

        Assert.True(response.StatusCode == HttpStatusCode.OK, body);
    }

    private static async Task<SharedSessionResponse> StartFromWorkoutSet(
        HttpClient client,
        AuthEndpointTests.AuthResponse actor,
        Guid workoutSetId)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(actor.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/shared-sessions/from-workout-set",
            new StartSharedSessionFromWorkoutSetRequest(workoutSetId, null));
        var body = await response.Content.ReadAsStringAsync();

        Assert.True(response.StatusCode == HttpStatusCode.Created, body);

        var session = await response.Content.ReadFromJsonAsync<SharedSessionResponse>();

        Assert.NotNull(session);
        return session;
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
        int? Seconds,
        bool? IsDone = null);

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

    private sealed record SharedSessionResponse(
        Guid Id,
        string TrainerUserId,
        string TraineeUserId,
        string TrainerEmail,
        string TraineeEmail,
        Guid? WorkoutSetId,
        string StartedByUserId,
        string StartedByRole,
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
        int ExerciseOrder,
        int SetIndex,
        int? Reps,
        decimal? Weight,
        int? Seconds,
        bool IsDone,
        DateTimeOffset? CompletedAt,
        string? UpdatedByUserId,
        DateTimeOffset? UpdatedAt);

    private sealed record WorkoutSetDetailResponse(
        Guid Id,
        string Name,
        IReadOnlyList<WorkoutSetRowResponse> Rows,
        IReadOnlyList<WorkoutSetAssignmentResponse> Assignments,
        DateTimeOffset CreatedAt,
        DateTimeOffset UpdatedAt);

    private sealed record WorkoutSetRowResponse(
        Guid Id,
        int ExerciseOrder,
        int SetIndex,
        string ExerciseName,
        string ExerciseType,
        int? Reps,
        decimal? Weight,
        int? Seconds);

    private sealed record WorkoutSetAssignmentResponse(
        string TraineeUserId,
        string TraineeEmail,
        string TraineeDisplayName,
        DateTimeOffset AssignedAt);
}
