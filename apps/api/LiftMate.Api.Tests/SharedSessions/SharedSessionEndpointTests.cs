using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using LiftMate.Api.Data;
using LiftMate.Api.Tests.Auth;
using LiftMate.Api.TrainingProgress;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

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
        Assert.Equal("Full body", session.WorkoutSetName);
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
                Assert.NotNull(first.ExerciseId);
                Assert.NotNull(first.WorkoutSetRowId);
                Assert.False(first.IsDone);
                Assert.Null(first.CompletedAt);
            },
            second =>
            {
                Assert.Equal(firstExerciseId(session), second.ExerciseId);
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
    public async Task ArchiveRejectsActiveSessionButPreservesCompletedHistoryAndProgress()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Push A", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var active = await StartFromWorkoutSet(client, trainee, workoutSet.Id);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var blockedDelete = await client.DeleteAsync($"/workout-sets/{workoutSet.Id}");

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var completed = await client.PostAsync($"/shared-sessions/{active.Id}/complete", null);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var archived = await client.DeleteAsync($"/workout-sets/{workoutSet.Id}");

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var restart = await client.PostAsJsonAsync(
            "/shared-sessions/from-workout-set",
            new StartSharedSessionFromWorkoutSetRequest(workoutSet.Id, null));

        Assert.Equal(HttpStatusCode.Conflict, blockedDelete.StatusCode);
        Assert.Equal(HttpStatusCode.OK, completed.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, archived.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, restart.StatusCode);

        using var scope = factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var savedSet = await dbContext.WorkoutSets
            .Include(set => set.Rows)
            .Include(set => set.Assignments)
            .SingleAsync(set => set.Id == workoutSet.Id);
        var savedSession = await dbContext.SharedSessions.SingleAsync(session => session.Id == active.Id);
        var savedProgress = await dbContext.WorkoutProgresses.SingleAsync(
            progress => progress.SourceSessionId == active.Id);

        Assert.NotNull(savedSet.DeletedAt);
        Assert.NotEmpty(savedSet.Rows);
        Assert.Empty(savedSet.Assignments);
        Assert.Equal("completed", savedSession.Status);
        Assert.Equal(workoutSet.Id, savedProgress.WorkoutSetId);
    }

    [Fact]
    public async Task ConcurrentStartAndArchiveNeverLeaveActiveSessionForArchivedSet()
    {
        using var setupClient = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(setupClient, "trainer");
        var trainee = await AuthEndpointTests.Register(setupClient, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(setupClient, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(setupClient, trainer, "Concurrent A", DefaultWorkoutSetRows());
        await AssignWorkoutSet(setupClient, trainer, workoutSet.Id, [trainee.User.Id]);

        using var startClient = factory.CreateClient();
        startClient.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        using var deleteClient = factory.CreateClient();
        deleteClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);

        var startTask = startClient.PostAsJsonAsync(
            "/shared-sessions/from-workout-set",
            new StartSharedSessionFromWorkoutSetRequest(workoutSet.Id, null));
        var deleteTask = deleteClient.DeleteAsync($"/workout-sets/{workoutSet.Id}");
        await Task.WhenAll(startTask, deleteTask);

        var startResponse = await startTask;
        var deleteResponse = await deleteTask;
        var startBody = await startResponse.Content.ReadAsStringAsync();
        var deleteBody = await deleteResponse.Content.ReadAsStringAsync();
        Assert.True(
            startResponse.StatusCode is HttpStatusCode.Created or HttpStatusCode.NotFound,
            $"Unexpected start response: {(int)startResponse.StatusCode} {startBody}");
        Assert.True(
            deleteResponse.StatusCode is HttpStatusCode.NoContent or HttpStatusCode.Conflict,
            $"Unexpected delete response: {(int)deleteResponse.StatusCode} {deleteBody}");

        using var scope = factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var deletedAt = await dbContext.WorkoutSets
            .Where(set => set.Id == workoutSet.Id)
            .Select(set => set.DeletedAt)
            .SingleAsync();
        var hasActiveSession = await dbContext.SharedSessions.AnyAsync(
            session => session.WorkoutSetId == workoutSet.Id && session.Status == "active");

        Assert.False(deletedAt is not null && hasActiveSession);
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
        Assert.Equal(updated.RestSeconds, updated.RestTimer.TotalSeconds);
        Assert.NotNull(updated.RestTimer.EndsAt);
        Assert.Equal(HttpStatusCode.OK, trainerRead.StatusCode);
        Assert.True(trainerValue.IsDone);
        Assert.NotNull(trainerValue.CompletedAt);
    }

    [Fact]
    public async Task SelfStartedTraineeCanControlPersistentRestTimer()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Rest timer", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var session = await StartFromWorkoutSet(client, trainee, workoutSet.Id);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var startResponse = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/rest",
            new { action = "start", deltaSeconds = (int?)null });
        var started = await startResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();

        var addResponse = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/rest",
            new { action = "add", deltaSeconds = 15 });
        var added = await addResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();

        var pauseResponse = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/rest",
            new { action = "pause", deltaSeconds = (int?)null });
        var paused = await pauseResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();

        var resetResponse = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/rest",
            new { action = "reset", deltaSeconds = (int?)null });
        var reset = await resetResponse.Content.ReadFromJsonAsync<SharedSessionResponse>();

        Assert.Equal(HttpStatusCode.OK, startResponse.StatusCode);
        Assert.NotNull(started?.RestTimer.EndsAt);
        Assert.Equal(HttpStatusCode.OK, addResponse.StatusCode);
        Assert.Equal(session.RestSeconds + 15, added?.RestTimer.TotalSeconds);
        Assert.InRange(added?.RestTimer.RemainingSeconds ?? 0, session.RestSeconds + 13, session.RestSeconds + 15);
        Assert.Equal(HttpStatusCode.OK, pauseResponse.StatusCode);
        Assert.Null(paused?.RestTimer.EndsAt);
        Assert.Equal(HttpStatusCode.OK, resetResponse.StatusCode);
        Assert.Equal(session.RestSeconds, reset?.RestTimer.TotalSeconds);
        Assert.Equal(session.RestSeconds, reset?.RestTimer.RemainingSeconds);
        Assert.Null(reset?.RestTimer.EndsAt);
        Assert.True((reset?.Version ?? 0) > session.Version);
    }

    [Fact]
    public async Task TrainerLedTraineeCannotControlRestTimer()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var session = await CreateSession(client, trainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var response = await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/rest",
            new { action = "start", deltaSeconds = (int?)null });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task ConcurrentRestAddsPreserveBothDeltasAndVersions()
    {
        using var setupClient = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(setupClient, "trainer");
        var trainee = await AuthEndpointTests.Register(setupClient, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(setupClient, trainer, trainee);
        var session = await CreateSession(setupClient, trainer, trainee);
        using var firstClient = factory.CreateClient();
        using var secondClient = factory.CreateClient();
        firstClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        secondClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);

        var responses = await Task.WhenAll(
            firstClient.PatchAsJsonAsync(
                $"/shared-sessions/{session.Id}/rest",
                new { action = "add", deltaSeconds = 15 }),
            secondClient.PatchAsJsonAsync(
                $"/shared-sessions/{session.Id}/rest",
                new { action = "add", deltaSeconds = 15 }));

        Assert.All(responses, response => Assert.Equal(HttpStatusCode.OK, response.StatusCode));
        setupClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var canonical = await setupClient.GetFromJsonAsync<SharedSessionResponse>(
            $"/shared-sessions/{session.Id}");

        Assert.NotNull(canonical);
        Assert.Equal(120, canonical.RestTimer.TotalSeconds);
        Assert.Equal(120, canonical.RestTimer.RemainingSeconds);
        Assert.Equal(session.Version + 2, canonical.Version);
    }

    [Fact]
    public async Task SessionSnapshotsWorkoutSetRestSeconds()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(
            client,
            trainer,
            "Rest snapshot",
            DefaultWorkoutSetRows(),
            restSeconds: 120);
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);

        var session = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        Assert.Equal(120, session.RestSeconds);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var update = await client.PutAsJsonAsync(
            $"/workout-sets/{workoutSet.Id}",
            new UpdateWorkoutSetRequest(
                workoutSet.Name,
                workoutSet.Rows
                    .Select(row => new WorkoutSetRowRequest(
                        row.ExerciseOrder,
                        row.SetIndex,
                        row.ExerciseName,
                        row.ExerciseType,
                        row.Reps,
                        row.Weight,
                        row.Seconds,
                        row.Id,
                        row.ExerciseId))
                    .ToArray(),
                RestSeconds: 60));
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var read = await client.GetFromJsonAsync<SharedSessionResponse>(
            $"/shared-sessions/{session.Id}");

        Assert.NotNull(read);
        Assert.Equal(120, read.RestSeconds);
    }

    [Fact]
    public async Task CompleteAndCancelLifecycleIsTerminalAndIdempotent()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var completedSession = await CreateSession(client, trainer, trainee);
        Assert.Equal(90, completedSession.RestSeconds);
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

        using (var scope = factory.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var streak = await dbContext.TraineeWeeklyStreaks.SingleAsync(
                item => item.TraineeUserId == trainee.User.Id);
            Assert.Equal(1, streak.CurrentStreakAtLastActiveWeek);
            Assert.Equal(1, streak.BestStreak);
            Assert.Equal(completed.ClosedAt, streak.LastCompletedSessionAt);
        }

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
    public async Task ConcurrentValueUpdatesHaveDistinctVersionsAndCanonicalResult()
    {
        using var setupClient = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(setupClient, "trainer");
        var trainee = await AuthEndpointTests.Register(setupClient, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(setupClient, trainer, trainee);
        var session = await CreateSession(setupClient, trainer, trainee);
        var value = Assert.Single(session.Values);

        using var firstClient = factory.CreateClient();
        using var secondClient = factory.CreateClient();
        firstClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        secondClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);

        var responses = await Task.WhenAll(
            firstClient.PatchAsJsonAsync(
                $"/shared-sessions/{session.Id}/values/{value.Id}",
                new UpdateSharedSessionValueRequest(8, 42.5m, null)),
            secondClient.PatchAsJsonAsync(
                $"/shared-sessions/{session.Id}/values/{value.Id}",
                new UpdateSharedSessionValueRequest(10, 45m, null)));

        Assert.All(responses, response => Assert.NotEqual(HttpStatusCode.InternalServerError, response.StatusCode));
        Assert.All(responses, response => Assert.Equal(HttpStatusCode.OK, response.StatusCode));

        var snapshots = await Task.WhenAll(
            responses.Select(response => response.Content.ReadFromJsonAsync<SharedSessionResponse>()));
        Assert.All(snapshots, Assert.NotNull);
        Assert.Equal(2, snapshots.Select(snapshot => snapshot!.Version).Distinct().Count());

        setupClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var canonical = await setupClient.GetFromJsonAsync<SharedSessionResponse>($"/shared-sessions/{session.Id}");
        Assert.NotNull(canonical);
        var latest = snapshots.MaxBy(snapshot => snapshot!.Version)!;

        Assert.Equal(latest!.Version, canonical.Version);
        Assert.Equal(Assert.Single(latest.Values).Reps, Assert.Single(canonical.Values).Reps);
        Assert.Equal(Assert.Single(latest.Values).Weight, Assert.Single(canonical.Values).Weight);
    }

    [Fact]
    public async Task ConcurrentValueUpdateAndCompleteHaveLinearTerminalResult()
    {
        using var setupClient = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(setupClient, "trainer");
        var trainee = await AuthEndpointTests.Register(setupClient, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(setupClient, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(setupClient, trainer, "Concurrent completion", DefaultWorkoutSetRows());
        await AssignWorkoutSet(setupClient, trainer, workoutSet.Id, [trainee.User.Id]);
        var session = await StartFromWorkoutSet(setupClient, trainer, workoutSet.Id, trainee.User.Id);
        var value = Assert.Single(session.Values);

        using var updateClient = factory.CreateClient();
        using var completeClient = factory.CreateClient();
        updateClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        completeClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);

        var updateTask = updateClient.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/values/{value.Id}",
            new UpdateSharedSessionValueRequest(9, 55m, null));
        var completeTask = completeClient.PostAsync($"/shared-sessions/{session.Id}/complete", null);
        await Task.WhenAll(updateTask, completeTask);

        var updateResponse = await updateTask;
        var completeResponse = await completeTask;
        Assert.NotEqual(HttpStatusCode.InternalServerError, updateResponse.StatusCode);
        Assert.NotEqual(HttpStatusCode.InternalServerError, completeResponse.StatusCode);
        Assert.Contains(updateResponse.StatusCode, new[] { HttpStatusCode.OK, HttpStatusCode.Conflict });
        Assert.Equal(HttpStatusCode.OK, completeResponse.StatusCode);

        setupClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var terminal = await setupClient.GetFromJsonAsync<SharedSessionResponse>($"/shared-sessions/{session.Id}");
        Assert.NotNull(terminal);
        Assert.Equal("completed", terminal.Status);
        Assert.NotNull(terminal.ClosedAt);

        var updateWon = updateResponse.StatusCode == HttpStatusCode.OK;
        Assert.Equal(updateWon ? 3 : 2, terminal.Version);
        Assert.Equal(updateWon ? 9 : 6, Assert.Single(terminal.Values).Reps);

        using var scope = factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var progress = await dbContext.WorkoutProgresses
            .Include(item => item.Values)
            .SingleAsync(item => item.SourceSessionId == session.Id);
        Assert.Equal(Assert.Single(terminal.Values).Reps, Assert.Single(progress.Values).Reps);
        Assert.Equal(Assert.Single(terminal.Values).Weight, Assert.Single(progress.Values).Weight);
    }

    [Fact]
    public async Task ConcurrentValueUpdateAndCancelHaveLinearTerminalResult()
    {
        using var setupClient = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(setupClient, "trainer");
        var trainee = await AuthEndpointTests.Register(setupClient, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(setupClient, trainer, trainee);
        var session = await CreateSession(setupClient, trainer, trainee);
        var value = Assert.Single(session.Values);

        using var updateClient = factory.CreateClient();
        using var cancelClient = factory.CreateClient();
        updateClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        cancelClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);

        var updateTask = updateClient.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/values/{value.Id}",
            new UpdateSharedSessionValueRequest(9, 55m, null));
        var cancelTask = cancelClient.PostAsync($"/shared-sessions/{session.Id}/cancel", null);
        await Task.WhenAll(updateTask, cancelTask);

        var updateResponse = await updateTask;
        var cancelResponse = await cancelTask;
        Assert.NotEqual(HttpStatusCode.InternalServerError, updateResponse.StatusCode);
        Assert.NotEqual(HttpStatusCode.InternalServerError, cancelResponse.StatusCode);
        Assert.Contains(updateResponse.StatusCode, new[] { HttpStatusCode.OK, HttpStatusCode.Conflict });
        Assert.Equal(HttpStatusCode.OK, cancelResponse.StatusCode);

        setupClient.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var terminal = await setupClient.GetFromJsonAsync<SharedSessionResponse>($"/shared-sessions/{session.Id}");
        Assert.NotNull(terminal);
        Assert.Equal("cancelled", terminal.Status);
        Assert.NotNull(terminal.ClosedAt);

        var updateWon = updateResponse.StatusCode == HttpStatusCode.OK;
        Assert.Equal(updateWon ? 3 : 2, terminal.Version);
        Assert.Equal(updateWon ? 9 : 6, Assert.Single(terminal.Values).Reps);
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
    public async Task CompletionProjectsEverySeriesAndNextSessionUsesSavedValues()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Progress plan", AllWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var firstSession = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        var firstValue = firstSession.Values.First();

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var update = await client.PatchAsJsonAsync(
            $"/shared-sessions/{firstSession.Id}/values/{firstValue.Id}",
            new UpdateSharedSessionValueRequest(9, 55m, null, false));
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);

        var complete = await client.PostAsync($"/shared-sessions/{firstSession.Id}/complete", null);
        var repeated = await client.PostAsync($"/shared-sessions/{firstSession.Id}/complete", null);

        Assert.Equal(HttpStatusCode.OK, complete.StatusCode);
        Assert.Equal(HttpStatusCode.OK, repeated.StatusCode);

        using (var scope = factory.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var progress = await dbContext.WorkoutProgresses
                .Include(item => item.Values)
                .SingleAsync(item =>
                    item.TraineeUserId == trainee.User.Id &&
                    item.WorkoutSetId == workoutSet.Id);

            Assert.Equal(firstSession.Id, progress.SourceSessionId);
            Assert.Equal(firstSession.Values.Count, progress.Values.Count);
            Assert.Contains(progress.Values, value =>
                value.WorkoutSetRowId == firstValue.WorkoutSetRowId &&
                value.Reps == 9 &&
                value.Weight == 55m);
            Assert.Contains(progress.Values, value =>
                value.WorkoutSetRowId != firstValue.WorkoutSetRowId &&
                value.Reps == 6);
        }

        var nextSession = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        var projected = Assert.Single(
            nextSession.Values,
            value => value.WorkoutSetRowId == firstValue.WorkoutSetRowId);

        Assert.Equal(9, projected.Reps);
        Assert.Equal(55m, projected.Weight);
    }

    [Fact]
    public async Task SecondCompletionForSameAssignedSetReplacesProgress()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(
            client,
            trainer,
            "Repeated progress",
            DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);

        var first = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var firstComplete = await client.PostAsync(
            $"/shared-sessions/{first.Id}/complete",
            null);
        Assert.Equal(HttpStatusCode.OK, firstComplete.StatusCode);

        var second = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        var secondValue = Assert.Single(second.Values);
        var update = await client.PatchAsJsonAsync(
            $"/shared-sessions/{second.Id}/values/{secondValue.Id}",
            new UpdateSharedSessionValueRequest(11, 65m, null, false));
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);

        var secondComplete = await client.PostAsync(
            $"/shared-sessions/{second.Id}/complete",
            null);

        Assert.Equal(HttpStatusCode.OK, secondComplete.StatusCode);

        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var progress = await dbContext.WorkoutProgresses
            .Include(item => item.Values)
            .SingleAsync(item =>
                item.TraineeUserId == trainee.User.Id &&
                item.WorkoutSetId == workoutSet.Id);

        Assert.Equal(second.Id, progress.SourceSessionId);
        var projected = Assert.Single(progress.Values);
        Assert.Equal(11, projected.Reps);
        Assert.Equal(65m, projected.Weight);
    }

    [Fact]
    public async Task ExistingProgressProjectionUsesSetBasedReplacement()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(
            client,
            trainer,
            "Set-based progress",
            DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);

        var first = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var firstComplete = await client.PostAsync(
            $"/shared-sessions/{first.Id}/complete",
            null);
        Assert.Equal(HttpStatusCode.OK, firstComplete.StatusCode);

        var second = await StartFromWorkoutSet(client, trainer, workoutSet.Id, trainee.User.Id);

        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        await using var transaction = await dbContext.Database.BeginTransactionAsync();
        var persistedSession = await dbContext.SharedSessions
            .Include(item => item.Values)
            .SingleAsync(item => item.Id == second.Id);
        var projector = new WorkoutProgressProjector(dbContext);

        await projector.ProjectAsync(
            persistedSession,
            DateTimeOffset.UtcNow.AddMinutes(1),
            CancellationToken.None);

        Assert.DoesNotContain(
            dbContext.ChangeTracker.Entries<WorkoutProgress>(),
            entry => entry.State is EntityState.Modified or EntityState.Deleted);
        Assert.DoesNotContain(
            dbContext.ChangeTracker.Entries<WorkoutProgressValue>(),
            entry => entry.State is EntityState.Modified or EntityState.Deleted);
        Assert.All(
            dbContext.ChangeTracker.Entries<WorkoutProgressValue>(),
            entry => Assert.Equal(EntityState.Added, entry.State));

        await transaction.RollbackAsync();
    }

    [Fact]
    public async Task TrainerCompletionReplacesProgressAfterWorkoutSetRowsChange()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(
            client,
            trainer,
            "Changed progress rows",
            DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var originalRow = Assert.Single(workoutSet.Rows);

        var first = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var firstComplete = await client.PostAsync(
            $"/shared-sessions/{first.Id}/complete",
            null);
        Assert.Equal(HttpStatusCode.OK, firstComplete.StatusCode);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var updateResponse = await client.PutAsJsonAsync(
            $"/workout-sets/{workoutSet.Id}",
            new UpdateWorkoutSetRequest(
                workoutSet.Name,
                [
                    new WorkoutSetRowRequest(
                        1,
                        1,
                        "Bench press",
                        "repsWeight",
                        8,
                        45m,
                        null,
                        null,
                        originalRow.ExerciseId),
                    new WorkoutSetRowRequest(
                        1,
                        2,
                        "Bench press",
                        "repsWeight",
                        6,
                        50m,
                        null,
                        null,
                        originalRow.ExerciseId),
                ]));
        Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);

        var second = await StartFromWorkoutSet(client, trainer, workoutSet.Id, trainee.User.Id);
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var secondComplete = await client.PostAsync(
            $"/shared-sessions/{second.Id}/complete",
            null);
        var completionBody = await secondComplete.Content.ReadAsStringAsync();

        Assert.True(secondComplete.StatusCode == HttpStatusCode.OK, completionBody);
        var completed = await secondComplete.Content.ReadFromJsonAsync<SharedSessionResponse>();
        Assert.NotNull(completed);
        Assert.Equal("completed", completed.Status);

        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var progressItems = await dbContext.WorkoutProgresses
            .Include(item => item.Values)
            .Where(item =>
                item.TraineeUserId == trainee.User.Id &&
                item.WorkoutSetId == workoutSet.Id)
            .ToListAsync();
        var progress = Assert.Single(progressItems);
        var expectedRowIds = second.Values
            .Select(value => value.WorkoutSetRowId!.Value)
            .Order()
            .ToArray();
        var actualRowIds = progress.Values
            .Select(value => value.WorkoutSetRowId)
            .Order()
            .ToArray();

        Assert.Equal(second.Id, progress.SourceSessionId);
        Assert.Equal(expectedRowIds, actualRowIds);
        Assert.DoesNotContain(originalRow.Id, actualRowIds);
    }

    [Fact]
    public async Task UnassignmentKeepsProgressAndReassignmentRestoresIt()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Persistent plan", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var session = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        var value = Assert.Single(session.Values);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        await client.PatchAsJsonAsync(
            $"/shared-sessions/{session.Id}/values/{value.Id}",
            new UpdateSharedSessionValueRequest(10, 60m, null, false));
        await client.PostAsync($"/shared-sessions/{session.Id}/complete", null);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var unassign = await client.DeleteAsync(
            $"/workout-sets/{workoutSet.Id}/assignments/{trainee.User.Id}");
        Assert.Equal(HttpStatusCode.NoContent, unassign.StatusCode);
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);

        var restored = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        var restoredValue = Assert.Single(restored.Values);

        Assert.Equal(10, restoredValue.Reps);
        Assert.Equal(60m, restoredValue.Weight);
    }

    [Fact]
    public async Task CancellationAndAdHocCompletionDoNotCreateProgress()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "No progress", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var cancelled = await StartFromWorkoutSet(client, trainee, workoutSet.Id);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        await client.PostAsync($"/shared-sessions/{cancelled.Id}/cancel", null);
        var adHoc = await CreateSession(client, trainer, trainee);
        await client.PostAsync($"/shared-sessions/{adHoc.Id}/complete", null);

        using var scope = factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.False(await dbContext.WorkoutProgresses.AnyAsync(item =>
            item.TraineeUserId == trainee.User.Id));
    }

    [Fact]
    public async Task OlderCompletionCannotReplaceNewerProjection()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Ordering", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var first = await StartFromWorkoutSet(client, trainee, workoutSet.Id);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        await client.PostAsync($"/shared-sessions/{first.Id}/complete", null);

        Guid sourceSessionId;
        await using (var scope = factory.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var progress = await dbContext.WorkoutProgresses
                .Include(item => item.Values)
                .SingleAsync(item => item.TraineeUserId == trainee.User.Id);
            sourceSessionId = progress.SourceSessionId;
            progress.SourceCompletedAt = DateTimeOffset.UtcNow.AddHours(1);
            Assert.Single(progress.Values).Weight = 99m;
            await dbContext.SaveChangesAsync();
        }

        var older = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        var olderValue = Assert.Single(older.Values);
        await client.PatchAsJsonAsync(
            $"/shared-sessions/{older.Id}/values/{olderValue.Id}",
            new UpdateSharedSessionValueRequest(8, 45m, null, false));
        await client.PostAsync($"/shared-sessions/{older.Id}/complete", null);

        await using var verificationScope = factory.Services.CreateAsyncScope();
        var verificationContext = verificationScope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var unchanged = await verificationContext.WorkoutProgresses
            .Include(item => item.Values)
            .SingleAsync(item => item.TraineeUserId == trainee.User.Id);

        Assert.Equal(sourceSessionId, unchanged.SourceSessionId);
        Assert.Equal(99m, Assert.Single(unchanged.Values).Weight);
    }

    [Fact]
    public async Task NextSessionUsesCurrentTemplateWithProjectedMatchesAndNewDefaults()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Template merge", DefaultWorkoutSetRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var originalRow = Assert.Single(workoutSet.Rows);
        var first = await StartFromWorkoutSet(client, trainee, workoutSet.Id);
        var firstValue = Assert.Single(first.Values);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        await client.PatchAsJsonAsync(
            $"/shared-sessions/{first.Id}/values/{firstValue.Id}",
            new UpdateSharedSessionValueRequest(10, 60m, null, false));
        await client.PostAsync($"/shared-sessions/{first.Id}/complete", null);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var updateResponse = await client.PutAsJsonAsync(
            $"/workout-sets/{workoutSet.Id}",
            new UpdateWorkoutSetRequest(
                workoutSet.Name,
                [
                    new WorkoutSetRowRequest(
                        1,
                        1,
                        "Renamed bench",
                        "repsWeight",
                        6,
                        40m,
                        null,
                        originalRow.Id,
                        originalRow.ExerciseId),
                    new WorkoutSetRowRequest(
                        1,
                        2,
                        "Renamed bench",
                        "repsWeight",
                        5,
                        35m,
                        null,
                        null,
                        originalRow.ExerciseId),
                ]));
        Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);

        var next = await StartFromWorkoutSet(client, trainee, workoutSet.Id);

        Assert.Collection(
            next.Values,
            projected =>
            {
                Assert.Equal("Renamed bench", projected.ExerciseName);
                Assert.Equal(10, projected.Reps);
                Assert.Equal(60m, projected.Weight);
            },
            added =>
            {
                Assert.Equal("Renamed bench", added.ExerciseName);
                Assert.Equal(5, added.Reps);
                Assert.Equal(35m, added.Weight);
            });
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
        IReadOnlyList<WorkoutSetRowRequest> rows,
        int? restSeconds = null)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/workout-sets",
            new CreateWorkoutSetRequest(name, rows, restSeconds));
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

    private static Guid? firstExerciseId(SharedSessionResponse session)
    {
        return session.Values.First().ExerciseId;
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
        IReadOnlyList<WorkoutSetRowRequest> Rows,
        int? RestSeconds = null);

    private sealed record UpdateWorkoutSetRequest(
        string Name,
        IReadOnlyList<WorkoutSetRowRequest> Rows,
        int? RestSeconds = null);

    private sealed record WorkoutSetRowRequest(
        int ExerciseOrder,
        int SetIndex,
        string ExerciseName,
        string ExerciseType,
        int? Reps,
        decimal? Weight,
        int? Seconds,
        Guid? Id = null,
        Guid? ExerciseId = null);

    private sealed record AssignWorkoutSetRequest(IReadOnlyList<string> TraineeUserIds);

    private sealed record ClaimTrainerInviteCodeRequest(string Code);

    private sealed record SharedSessionResponse(
        Guid Id,
        string TrainerUserId,
        string TraineeUserId,
        string TrainerEmail,
        string TraineeEmail,
        Guid? WorkoutSetId,
        string WorkoutSetName,
        int RestSeconds,
        string StartedByUserId,
        string StartedByRole,
        string Status,
        long Version,
        DateTimeOffset CreatedAt,
        DateTimeOffset UpdatedAt,
        DateTimeOffset? ClosedAt,
        SharedSessionRestTimerResponse RestTimer,
        IReadOnlyList<SharedSessionValueResponse> Values);

    private sealed record SharedSessionRestTimerResponse(
        int TotalSeconds,
        int RemainingSeconds,
        DateTimeOffset? EndsAt,
        DateTimeOffset ServerNow);

    private sealed record SharedSessionValueResponse(
        Guid Id,
        Guid? ExerciseId,
        Guid? WorkoutSetRowId,
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
        int RestSeconds,
        IReadOnlyList<WorkoutSetRowResponse> Rows,
        IReadOnlyList<WorkoutSetAssignmentResponse> Assignments,
        DateTimeOffset CreatedAt,
        DateTimeOffset UpdatedAt);

    private sealed record WorkoutSetRowResponse(
        Guid Id,
        Guid ExerciseId,
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
