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
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);

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
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
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
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
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
    public async Task TrainerCanUpdateTrainerLedValueAndTraineeIsReadOnly()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
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

        Assert.Equal(HttpStatusCode.Forbidden, traineeUpdate.StatusCode);
    }

    [Fact]
    public async Task InvalidValueUpdateReturnsBadRequestWithoutAdvancingVersion()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var session = await CreateSession(
            client,
            trainer,
            trainee,
            new CreateSharedSessionValueRequest("Plank", "time", 1, null, null, 60));
        var value = Assert.Single(session.Values);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
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
    public async Task TrainerCanStartFromAssignedWorkoutSetWithSnapshotAndOrigin()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Full body", AllWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);

        var session = await StartFromWorkoutSet(client, trainer, workoutSet.Id, trainee.User.Id);

        Assert.Equal(trainer.User.Id, session.TrainerUserId);
        Assert.Equal(trainee.User.Id, session.TraineeUserId);
        Assert.Equal(workoutSet.Id, session.WorkoutSetId);
        Assert.Equal(trainer.User.Id, session.StartedByUserId);
        Assert.Equal("trainer", session.StartedByRole);
        Assert.Equal(3, session.Values.Count);
        Assert.Collection(
            session.Values,
            first =>
            {
                Assert.Equal(1, first.ExerciseOrder);
                Assert.Equal(1, first.SetIndex);
                Assert.Equal("Bench press", first.ExerciseName);
                Assert.False(first.IsDone);
                Assert.Null(first.CompletedAt);
            },
            second =>
            {
                Assert.Equal(1, second.ExerciseOrder);
                Assert.Equal(2, second.SetIndex);
                Assert.Equal("Bench press", second.ExerciseName);
            },
            third =>
            {
                Assert.Equal(2, third.ExerciseOrder);
                Assert.Equal("Plank", third.ExerciseName);
                Assert.Equal(45, third.Seconds);
            });
    }

    [Fact]
    public async Task TraineeCanSelfStartFromAssignedWorkoutSet()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Solo day", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);

        var session = await StartFromWorkoutSet(client, trainee, workoutSet.Id);

        Assert.Equal(trainer.User.Id, session.TrainerUserId);
        Assert.Equal(trainee.User.Id, session.TraineeUserId);
        Assert.Equal(workoutSet.Id, session.WorkoutSetId);
        Assert.Equal(trainee.User.Id, session.StartedByUserId);
        Assert.Equal("trainee", session.StartedByRole);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var trainerRead = await client.GetAsync($"/shared-sessions/{session.Id}");

        Assert.Equal(HttpStatusCode.OK, trainerRead.StatusCode);
    }

    [Fact]
    public async Task UnrelatedTrainerCannotReadSelfStartedSession()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var otherTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Solo day", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var session = await StartFromWorkoutSet(client, trainee, workoutSet.Id);

        client.DefaultRequestHeaders.Authorization = Bearer(otherTrainer.AccessToken);
        var otherTrainerRead = await client.GetAsync($"/shared-sessions/{session.Id}");

        Assert.Equal(HttpStatusCode.Forbidden, otherTrainerRead.StatusCode);
    }

    [Fact]
    public async Task StartFromWorkoutSetRejectsUnassignedAndWrongTrainerStarts()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var otherTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var unrelatedTrainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Assigned", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var unassigned = await client.PostAsJsonAsync(
            "/shared-sessions/from-workout-set",
            new StartSharedSessionFromWorkoutSetRequest(workoutSet.Id, unrelatedTrainee.User.Id));

        client.DefaultRequestHeaders.Authorization = Bearer(otherTrainer.AccessToken);
        var wrongTrainer = await client.PostAsJsonAsync(
            "/shared-sessions/from-workout-set",
            new StartSharedSessionFromWorkoutSetRequest(workoutSet.Id, trainee.User.Id));

        client.DefaultRequestHeaders.Authorization = Bearer(unrelatedTrainee.AccessToken);
        var unrelatedTraineeStart = await client.PostAsJsonAsync(
            "/shared-sessions/from-workout-set",
            new StartSharedSessionFromWorkoutSetRequest(workoutSet.Id, null));

        Assert.Equal(HttpStatusCode.Forbidden, unassigned.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, wrongTrainer.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, unrelatedTraineeStart.StatusCode);
    }

    [Fact]
    public async Task StartFromWorkoutSetEnforcesOneActiveSessionAcrossStartModes()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Assigned", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var active = await StartFromWorkoutSet(client, trainer, workoutSet.Id, trainee.User.Id);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var duplicateSelfStart = await client.PostAsJsonAsync(
            "/shared-sessions/from-workout-set",
            new StartSharedSessionFromWorkoutSetRequest(workoutSet.Id, null));

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        await client.PostAsync($"/shared-sessions/{active.Id}/cancel", null);

        var afterClose = await StartFromWorkoutSet(client, trainee, workoutSet.Id);

        Assert.Equal(HttpStatusCode.Conflict, duplicateSelfStart.StatusCode);
        Assert.Equal("active", afterClose.Status);
        Assert.Equal("trainee", afterClose.StartedByRole);
    }

    [Fact]
    public async Task DoneStatePersistsAndSelfStartedTraineeCanUpdateValues()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Solo day", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var session = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        var value = Assert.Single(session.Values);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var update = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/values/{value.Id}",
            new UpdateSharedSessionValueRequest(8, 42.5m, null, true));
        var updated = await update.Content.ReadFromJsonAsync<SharedSessionResponse>();
        var updatedValue = Assert.Single(updated?.Values ?? []);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var trainerRead = await client.GetAsync($"/shared-sessions/{session.Id}");
        var trainerSession = await trainerRead.Content.ReadFromJsonAsync<SharedSessionResponse>();
        var trainerValue = Assert.Single(trainerSession?.Values ?? []);

        Assert.Equal(HttpStatusCode.OK, update.StatusCode);
        Assert.NotNull(updated);
        Assert.Equal(2, updated.Version);
        Assert.True(updatedValue.IsDone);
        Assert.NotNull(updatedValue.CompletedAt);
        Assert.Equal(8, updatedValue.Reps);
        Assert.Equal(42.5m, updatedValue.Weight);
        Assert.Equal(trainee.User.Id, updatedValue.UpdatedByUserId);
        Assert.Equal(HttpStatusCode.OK, trainerRead.StatusCode);
        Assert.True(trainerValue.IsDone);
        Assert.NotNull(trainerValue.CompletedAt);
    }

    [Fact]
    public async Task CompleteAndCancelLifecycleIsTerminalAndIdempotent()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
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

    [Fact]
    public async Task CreateRequiresTrainerTraineePairing()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var anotherTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var unpairedResponse = await client.PostAsJsonAsync(
            "/shared-sessions",
            CreateRequest(trainee.User.Email));

        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(anotherTrainer.AccessToken);
        var wrongTrainerResponse = await client.PostAsJsonAsync(
            "/shared-sessions",
            CreateRequest(trainee.User.Email));

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var pairedTrainerResponse = await client.PostAsJsonAsync(
            "/shared-sessions",
            CreateRequest(trainee.User.Email));

        Assert.Equal(HttpStatusCode.Forbidden, unpairedResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, wrongTrainerResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Created, pairedTrainerResponse.StatusCode);
    }

    [Fact]
    public async Task OldTrainerCannotAccessSessionAfterTraineeRePairs()
    {
        using var client = factory.CreateClient();
        var oldTrainer = await AuthEndpointTests.Register(client, "trainer");
        var newTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, oldTrainer, trainee);
        var session = await CreateSession(client, oldTrainer, trainee);
        var value = Assert.Single(session.Values);
        await PairingEndpointTests.PairTrainerAndTrainee(client, newTrainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(oldTrainer.AccessToken);
        var readResponse = await client.GetAsync($"/shared-sessions/{session.Id}");
        var updateResponse = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/values/{value.Id}",
            new UpdateSharedSessionValueRequest(8, 45m, null));
        var completeResponse = await client.PostAsync($"/shared-sessions/{session.Id}/complete", null);
        var cancelResponse = await client.PostAsync($"/shared-sessions/{session.Id}/cancel", null);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var traineeRead = await client.GetAsync($"/shared-sessions/{session.Id}");
        var cancelled = await traineeRead.Content.ReadFromJsonAsync<SharedSessionResponse>();

        Assert.Equal(HttpStatusCode.Forbidden, readResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, updateResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, completeResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, cancelResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, traineeRead.StatusCode);
        Assert.NotNull(cancelled);
        Assert.Equal("cancelled", cancelled.Status);
        Assert.Equal(2, cancelled.Version);
    }

    [Fact]
    public async Task InvalidRePairAttemptDoesNotCancelSessionOrRemoveOldTrainerAccess()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var session = await CreateSession(client, trainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var invalidClaim = await client.PostAsJsonAsync(
            "/trainee/trainer-link",
            new ClaimTrainerInviteCodeRequest("AAAAAA"));

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var readResponse = await client.GetAsync($"/shared-sessions/{session.Id}");
        var active = await readResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();

        Assert.Equal(HttpStatusCode.NotFound, invalidClaim.StatusCode);
        Assert.Equal(HttpStatusCode.OK, readResponse.StatusCode);
        Assert.NotNull(active);
        Assert.Equal("active", active.Status);
        Assert.Equal(1, active.Version);
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

    private static async Task<WorkoutSetDetailResponse> CreateWorkoutSet(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer,
        string name,
        IReadOnlyList<WorkoutSetRowRequest> rows)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/workout-sets",
            new CreateWorkoutSetRequest(name, rows));
        var body = await response.Content.ReadAsStringAsync();

        Assert.True(response.StatusCode == HttpStatusCode.Created, body);

        var workoutSet = await response.Content.ReadFromJsonAsync<WorkoutSetDetailResponse>();

        Assert.NotNull(workoutSet);
        return workoutSet;
    }

    private static async Task<WorkoutSetDetailResponse> AssignWorkoutSet(
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

        var workoutSet = await response.Content.ReadFromJsonAsync<WorkoutSetDetailResponse>();

        Assert.NotNull(workoutSet);
        return workoutSet;
    }

    private static async Task<SharedSessionResponse> StartFromWorkoutSet(
        HttpClient client,
        AuthEndpointTests.AuthResponse actor,
        Guid workoutSetId,
        string? traineeUserId = null)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(actor.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/shared-sessions/from-workout-set",
            new StartSharedSessionFromWorkoutSetRequest(workoutSetId, traineeUserId));
        var body = await response.Content.ReadAsStringAsync();

        Assert.True(response.StatusCode == HttpStatusCode.Created, body);

        var session = await response.Content.ReadFromJsonAsync<SharedSessionResponse>();

        Assert.NotNull(session);
        return session;
    }

    private static WorkoutSetRowRequest[] DefaultWorkoutSetRows()
    {
        return [new WorkoutSetRowRequest(1, 1, "Bench press", "repsWeight", 6, 40m, null)];
    }

    private static WorkoutSetRowRequest[] AllWorkoutSetRows()
    {
        return
        [
            new WorkoutSetRowRequest(1, 1, "Bench press", "repsWeight", 6, 40m, null),
            new WorkoutSetRowRequest(1, 2, "Bench press", "repsWeight", 6, 42.5m, null),
            new WorkoutSetRowRequest(2, 1, "Plank", "time", null, null, 45),
        ];
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

    private sealed record StartSharedSessionFromWorkoutSetRequest(
        Guid WorkoutSetId,
        string? TraineeUserId);

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

    private sealed record ClaimTrainerInviteCodeRequest(string Code);

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
