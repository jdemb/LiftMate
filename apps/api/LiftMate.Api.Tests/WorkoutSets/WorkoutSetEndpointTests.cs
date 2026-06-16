using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using LiftMate.Api.Tests.Auth;

namespace LiftMate.Api.Tests.WorkoutSets;

public sealed class WorkoutSetEndpointTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task TrainerCanCreateListDetailUpdateAndAssignedTraineeSeesLatestRows()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var firstTrainee = await AuthEndpointTests.Register(client, "trainee");
        var secondTrainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, firstTrainee);
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, secondTrainee);

        var created = await CreateWorkoutSet(client, trainer, "Full body A", AllExerciseTypeRows());
        Assert.Equal(3, created.Rows.Count);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var listResponse = await client.GetAsync("/workout-sets");
        var list = await listResponse.Content.ReadFromJsonAsync<IReadOnlyList<WorkoutSetSummaryResponse>>();

        Assert.Equal(HttpStatusCode.OK, listResponse.StatusCode);
        Assert.NotNull(list);
        var summary = Assert.Single(list, set => set.Id == created.Id);
        Assert.Equal(3, summary.ExerciseCount);
        Assert.Equal(3, summary.RowCount);
        Assert.Equal(0, summary.AssignedTrainees);

        var assigned = await AssignWorkoutSet(client, trainer, created.Id, [firstTrainee.User.Id, secondTrainee.User.Id]);
        Assert.Equal(2, assigned.Assignments.Count);

        client.DefaultRequestHeaders.Authorization = Bearer(firstTrainee.AccessToken);
        var traineeListResponse = await client.GetAsync("/trainee/workout-sets");
        var traineeList = await traineeListResponse.Content.ReadFromJsonAsync<IReadOnlyList<TraineeAssignedWorkoutSetResponse>>();

        Assert.Equal(HttpStatusCode.OK, traineeListResponse.StatusCode);
        Assert.NotNull(traineeList);
        var traineeSet = Assert.Single(traineeList);
        Assert.Equal(created.Id, traineeSet.Id);
        Assert.Equal("Full body A", traineeSet.Name);
        Assert.Equal(3, traineeSet.Rows.Count);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var updateResponse = await client.PutAsJsonAsync(
            $"/workout-sets/{created.Id}",
            new UpdateWorkoutSetRequest(
                "Full body B",
                [new WorkoutSetRowRequest(1, 1, "Squat", "repsWeight", 5, 100m, null)]));
        var updateBody = await updateResponse.Content.ReadAsStringAsync();

        Assert.True(updateResponse.StatusCode == HttpStatusCode.OK, updateBody);

        var updated = await updateResponse.Content.ReadFromJsonAsync<WorkoutSetDetailResponse>();

        Assert.NotNull(updated);
        Assert.Equal("Full body B", updated.Name);
        Assert.Single(updated.Rows);
        Assert.Equal(2, updated.Assignments.Count);

        client.DefaultRequestHeaders.Authorization = Bearer(firstTrainee.AccessToken);
        var traineeDetailResponse = await client.GetAsync($"/trainee/workout-sets/{created.Id}");
        var traineeDetail = await traineeDetailResponse.Content.ReadFromJsonAsync<TraineeAssignedWorkoutSetResponse>();

        Assert.Equal(HttpStatusCode.OK, traineeDetailResponse.StatusCode);
        Assert.NotNull(traineeDetail);
        Assert.Equal("Full body B", traineeDetail.Name);
        var row = Assert.Single(traineeDetail.Rows);
        Assert.Equal("Squat", row.ExerciseName);
        Assert.Equal(100m, row.Weight);
    }

    [Fact]
    public async Task UnrelatedUsersCannotReadOrMutateWorkoutSets()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var otherTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var unrelatedTrainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Upper body", DefaultRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);

        client.DefaultRequestHeaders.Authorization = Bearer(otherTrainer.AccessToken);
        var otherTrainerRead = await client.GetAsync($"/workout-sets/{workoutSet.Id}");
        var otherTrainerUpdate = await client.PutAsJsonAsync(
            $"/workout-sets/{workoutSet.Id}",
            new UpdateWorkoutSetRequest("Hijacked", DefaultRows()));
        var otherTrainerAssign = await client.PostAsJsonAsync(
            $"/workout-sets/{workoutSet.Id}/assignments",
            new AssignWorkoutSetRequest([trainee.User.Id]));
        var otherTrainerUnassign = await client.DeleteAsync(
            $"/workout-sets/{workoutSet.Id}/assignments/{trainee.User.Id}");

        client.DefaultRequestHeaders.Authorization = Bearer(unrelatedTrainee.AccessToken);
        var unrelatedTraineeList = await client.GetAsync("/trainee/workout-sets");
        var unrelatedTraineeSets = await unrelatedTraineeList.Content.ReadFromJsonAsync<IReadOnlyList<TraineeAssignedWorkoutSetResponse>>();
        var unrelatedTraineeRead = await client.GetAsync($"/trainee/workout-sets/{workoutSet.Id}");
        var traineeManagementAttempt = await client.GetAsync($"/workout-sets/{workoutSet.Id}");

        Assert.Equal(HttpStatusCode.NotFound, otherTrainerRead.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, otherTrainerUpdate.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, otherTrainerAssign.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, otherTrainerUnassign.StatusCode);
        Assert.Equal(HttpStatusCode.OK, unrelatedTraineeList.StatusCode);
        Assert.NotNull(unrelatedTraineeSets);
        Assert.Empty(unrelatedTraineeSets);
        Assert.Equal(HttpStatusCode.NotFound, unrelatedTraineeRead.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, traineeManagementAttempt.StatusCode);
    }

    [Fact]
    public async Task AssignmentsAreIdempotentAndInvalidMultiAssignIsAtomic()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var secondTrainee = await AuthEndpointTests.Register(client, "trainee");
        var unrelatedTrainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, secondTrainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Leg day", DefaultRows());

        var firstAssign = await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var repeatedAssign = await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var secondAssign = await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id, secondTrainee.User.Id]);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var duplicateAssign = await client.PostAsJsonAsync(
            $"/workout-sets/{workoutSet.Id}/assignments",
            new AssignWorkoutSetRequest([trainee.User.Id, trainee.User.Id]));
        var unrelatedAssign = await client.PostAsJsonAsync(
            $"/workout-sets/{workoutSet.Id}/assignments",
            new AssignWorkoutSetRequest([trainee.User.Id, unrelatedTrainee.User.Id]));
        var afterFailures = await ReadTrainerDetail(client, trainer, workoutSet.Id);

        Assert.Single(firstAssign.Assignments);
        Assert.Single(repeatedAssign.Assignments);
        Assert.Equal(2, secondAssign.Assignments.Count);
        Assert.Equal(HttpStatusCode.BadRequest, duplicateAssign.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, unrelatedAssign.StatusCode);
        Assert.Equal(2, afterFailures.Assignments.Count);
        Assert.Contains(afterFailures.Assignments, assignment => assignment.TraineeUserId == trainee.User.Id);
        Assert.Contains(afterFailures.Assignments, assignment => assignment.TraineeUserId == secondTrainee.User.Id);
    }

    [Fact]
    public async Task UnassignRemovesOnlyTargetTraineeAndLeavesSetForOthers()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var firstTrainee = await AuthEndpointTests.Register(client, "trainee");
        var secondTrainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, firstTrainee);
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, secondTrainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Pull day", DefaultRows());
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [firstTrainee.User.Id, secondTrainee.User.Id]);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var unassignResponse = await client.DeleteAsync(
            $"/workout-sets/{workoutSet.Id}/assignments/{firstTrainee.User.Id}");
        var detail = await ReadTrainerDetail(client, trainer, workoutSet.Id);

        client.DefaultRequestHeaders.Authorization = Bearer(firstTrainee.AccessToken);
        var firstTraineeRead = await client.GetAsync($"/trainee/workout-sets/{workoutSet.Id}");

        client.DefaultRequestHeaders.Authorization = Bearer(secondTrainee.AccessToken);
        var secondTraineeRead = await client.GetAsync($"/trainee/workout-sets/{workoutSet.Id}");

        Assert.Equal(HttpStatusCode.NoContent, unassignResponse.StatusCode);
        var assignment = Assert.Single(detail.Assignments);
        Assert.Equal(secondTrainee.User.Id, assignment.TraineeUserId);
        Assert.Equal(HttpStatusCode.NotFound, firstTraineeRead.StatusCode);
        Assert.Equal(HttpStatusCode.OK, secondTraineeRead.StatusCode);
    }

    [Fact]
    public async Task RePairingRemovesOldTrainerAssignmentsButInvalidClaimPreservesThem()
    {
        using var client = factory.CreateClient();
        var oldTrainer = await AuthEndpointTests.Register(client, "trainer");
        var newTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, oldTrainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, oldTrainer, "Old plan", DefaultRows());
        await AssignWorkoutSet(client, oldTrainer, workoutSet.Id, [trainee.User.Id]);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var invalidClaim = await client.PostAsJsonAsync(
            "/trainee/trainer-link",
            new ClaimTrainerInviteCodeRequest("AAAAAA"));
        var stillAssigned = await client.GetAsync($"/trainee/workout-sets/{workoutSet.Id}");

        await PairingEndpointTests.PairTrainerAndTrainee(client, newTrainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var afterRePairRead = await client.GetAsync($"/trainee/workout-sets/{workoutSet.Id}");
        var afterRePairList = await client.GetAsync("/trainee/workout-sets");
        var assignedSets = await afterRePairList.Content.ReadFromJsonAsync<IReadOnlyList<TraineeAssignedWorkoutSetResponse>>();

        var oldTrainerDetail = await ReadTrainerDetail(client, oldTrainer, workoutSet.Id);

        Assert.Equal(HttpStatusCode.NotFound, invalidClaim.StatusCode);
        Assert.Equal(HttpStatusCode.OK, stillAssigned.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, afterRePairRead.StatusCode);
        Assert.Equal(HttpStatusCode.OK, afterRePairList.StatusCode);
        Assert.NotNull(assignedSets);
        Assert.Empty(assignedSets);
        Assert.Empty(oldTrainerDetail.Assignments);
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
        var workoutSet = await response.Content.ReadFromJsonAsync<WorkoutSetDetailResponse>();

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
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

    private static async Task<WorkoutSetDetailResponse> ReadTrainerDetail(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer,
        Guid workoutSetId)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.GetAsync($"/workout-sets/{workoutSetId}");
        var workoutSet = await response.Content.ReadFromJsonAsync<WorkoutSetDetailResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(workoutSet);
        return workoutSet;
    }

    private static WorkoutSetRowRequest[] DefaultRows()
    {
        return [new WorkoutSetRowRequest(1, 1, "Bench press", "repsWeight", 6, 40m, null)];
    }

    private static WorkoutSetRowRequest[] AllExerciseTypeRows()
    {
        return
        [
            new WorkoutSetRowRequest(1, 1, "Bench press", "repsWeight", 6, 40m, null),
            new WorkoutSetRowRequest(2, 1, "Pull up", "repsOnly", 8, null, null),
            new WorkoutSetRowRequest(3, 1, "Plank", "time", null, null, 60),
        ];
    }

    private static AuthenticationHeaderValue Bearer(string accessToken)
    {
        return new AuthenticationHeaderValue("Bearer", accessToken);
    }

    private sealed record CreateWorkoutSetRequest(
        string Name,
        IReadOnlyList<WorkoutSetRowRequest> Rows);

    private sealed record UpdateWorkoutSetRequest(
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

    private sealed record WorkoutSetSummaryResponse(
        Guid Id,
        string Name,
        int ExerciseCount,
        int RowCount,
        int AssignedTrainees,
        DateTimeOffset CreatedAt,
        DateTimeOffset UpdatedAt);

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

    private sealed record TraineeAssignedWorkoutSetResponse(
        Guid Id,
        string Name,
        string TrainerDisplayName,
        IReadOnlyList<WorkoutSetRowResponse> Rows,
        DateTimeOffset AssignedAt,
        DateTimeOffset UpdatedAt);
}
