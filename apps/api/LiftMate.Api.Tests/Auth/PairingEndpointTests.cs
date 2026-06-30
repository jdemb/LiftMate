using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.RegularExpressions;
using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LiftMate.Api.Tests.Auth;

public sealed partial class PairingEndpointTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task TrainerCanGenerateStableInviteCode()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");

        var first = await GenerateTrainerInviteCode(client, trainer);
        var second = await GenerateTrainerInviteCode(client, trainer);

        Assert.Matches(InviteCodePattern(), first.Code);
        Assert.Equal(first.Code, second.Code);
    }

    [Fact]
    public async Task TraineeCanClaimTrainerInviteCodeWithNormalizedInput()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var inviteCode = await GenerateTrainerInviteCode(client, trainer);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var startedAt = DateTimeOffset.UtcNow;
        var claimResponse = await client.PostAsJsonAsync(
            "/trainee/trainer-link",
            new ClaimTrainerInviteCodeRequest($"  {inviteCode.Code.ToLowerInvariant()}  "));
        var completedAt = DateTimeOffset.UtcNow;
        var linked = await claimResponse.Content.ReadFromJsonAsync<AuthEndpointTests.UserResponse>();

        using var scope = factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var persisted = await dbContext.Users.SingleAsync(user => user.Id == trainee.User.Id);

        Assert.Equal(HttpStatusCode.OK, claimResponse.StatusCode);
        Assert.NotNull(linked);
        Assert.Equal(trainer.User.Id, linked.TrainerUserId);
        Assert.NotNull(persisted.TrainerLinkedAt);
        Assert.InRange(persisted.TrainerLinkedAt.Value, startedAt, completedAt);

        var meResponse = await client.GetAsync("/auth/me");
        var me = await meResponse.Content.ReadFromJsonAsync<AuthEndpointTests.UserResponse>();

        Assert.Equal(HttpStatusCode.OK, meResponse.StatusCode);
        Assert.Equal(trainer.User.Id, me?.TrainerUserId);
    }

    [Fact]
    public async Task TraineeCannotClaimInvalidCodeOrReassign()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var anotherTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var inviteCode = await GenerateTrainerInviteCode(client, trainer);
        var anotherInviteCode = await GenerateTrainerInviteCode(client, anotherTrainer);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var invalidFormatResponse = await client.PostAsJsonAsync(
            "/trainee/trainer-link",
            new ClaimTrainerInviteCodeRequest("ABC123"));
        var notFoundResponse = await client.PostAsJsonAsync(
            "/trainee/trainer-link",
            new ClaimTrainerInviteCodeRequest("AAAAAA"));

        var claimResponse = await client.PostAsJsonAsync(
            "/trainee/trainer-link",
            new ClaimTrainerInviteCodeRequest(inviteCode.Code));
        var reassignResponse = await client.PostAsJsonAsync(
            "/trainee/trainer-link",
            new ClaimTrainerInviteCodeRequest(anotherInviteCode.Code));
        var reassigned = await reassignResponse.Content.ReadFromJsonAsync<AuthEndpointTests.UserResponse>();

        Assert.Equal(HttpStatusCode.BadRequest, invalidFormatResponse.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, notFoundResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, claimResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, reassignResponse.StatusCode);
        Assert.Equal(anotherTrainer.User.Id, reassigned?.TrainerUserId);
    }

    [Fact]
    public async Task TrainerRelationshipSummaryReturnsInviteCodeAndLinkedTrainees()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var anotherTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var otherTrainee = await AuthEndpointTests.Register(client, "trainee");
        await PairTrainerAndTrainee(client, trainer, trainee);
        await PairTrainerAndTrainee(client, anotherTrainer, otherTrainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.GetAsync("/trainer/relationship");
        var summary = await response.Content.ReadFromJsonAsync<TrainerRelationshipSummaryResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(summary);
        Assert.Matches(InviteCodePattern(), summary.InviteCode);
        var linkedTrainee = Assert.Single(summary.Trainees);
        Assert.Equal(trainee.User.Id, linkedTrainee.Id);
        Assert.Equal(trainee.User.Email, linkedTrainee.Email);
        Assert.Equal(trainee.User.DisplayName, linkedTrainee.DisplayName);
        Assert.Null(linkedTrainee.ActiveSession);
    }

    [Fact]
    public async Task TrainerRelationshipSummaryReturnsPersistedConnectionTimestamp()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairTrainerAndTrainee(client, trainer, trainee);

        DateTimeOffset? linkedAt;
        using (var scope = factory.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            linkedAt = await dbContext.Users
                .Where(user => user.Id == trainee.User.Id)
                .Select(user => user.TrainerLinkedAt)
                .SingleAsync();
        }

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.GetAsync("/trainer/relationship");
        var summary = await response.Content.ReadFromJsonAsync<TrainerRelationshipSummaryResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(linkedAt);
        Assert.Equal(linkedAt, Assert.Single(summary!.Trainees).ConnectedAt);
    }

    [Fact]
    public async Task TrainerRelationshipSummaryFallsBackToOldestRefreshTokenForLegacyLink()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairTrainerAndTrainee(client, trainer, trainee);
        var registeredAt = new DateTimeOffset(2026, 3, 8, 10, 0, 0, TimeSpan.Zero);

        using (var scope = factory.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var user = await dbContext.Users.SingleAsync(value => value.Id == trainee.User.Id);
            user.TrainerLinkedAt = null;
            var oldestToken = await dbContext.RefreshTokens
                .Where(token => token.UserId == trainee.User.Id)
                .SingleAsync();
            oldestToken.CreatedAt = registeredAt;
            await dbContext.SaveChangesAsync();
        }

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.GetAsync("/trainer/relationship");
        var summary = await response.Content.ReadFromJsonAsync<TrainerRelationshipSummaryResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(registeredAt, Assert.Single(summary!.Trainees).ConnectedAt);
    }

    [Fact]
    public async Task TrainerRelationshipSummaryReturnsNullConnectionTimestampWithoutLegacyToken()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairTrainerAndTrainee(client, trainer, trainee);

        using (var scope = factory.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var user = await dbContext.Users.SingleAsync(value => value.Id == trainee.User.Id);
            user.TrainerLinkedAt = null;
            var tokens = await dbContext.RefreshTokens
                .Where(token => token.UserId == trainee.User.Id)
                .ToListAsync();
            dbContext.RefreshTokens.RemoveRange(tokens);
            await dbContext.SaveChangesAsync();
        }

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.GetAsync("/trainer/relationship");
        var summary = await response.Content.ReadFromJsonAsync<TrainerRelationshipSummaryResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Null(Assert.Single(summary!.Trainees).ConnectedAt);
    }

    [Fact]
    public async Task TrainerRelationshipSummaryIncludesLinkedTraineeActiveSession()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var otherTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var otherTrainee = await AuthEndpointTests.Register(client, "trainee");
        await PairTrainerAndTrainee(client, trainer, trainee);
        await PairTrainerAndTrainee(client, otherTrainer, otherTrainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Solo day");
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);
        var session = await StartFromWorkoutSet(client, trainee, workoutSet.Id);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.GetAsync("/trainer/relationship");
        var summary = await response.Content.ReadFromJsonAsync<TrainerRelationshipSummaryResponse>();

        client.DefaultRequestHeaders.Authorization = Bearer(otherTrainer.AccessToken);
        var otherResponse = await client.GetAsync("/trainer/relationship");
        var otherSummary = await otherResponse.Content.ReadFromJsonAsync<TrainerRelationshipSummaryResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(summary);
        var linkedTrainee = Assert.Single(summary.Trainees);
        Assert.Equal(trainee.User.Id, linkedTrainee.Id);
        Assert.NotNull(linkedTrainee.ActiveSession);
        Assert.Equal(session.Id, linkedTrainee.ActiveSession.SessionId);
        Assert.Equal(workoutSet.Id, linkedTrainee.ActiveSession.WorkoutSetId);
        Assert.Equal("Solo day", linkedTrainee.ActiveSession.WorkoutSetName);
        Assert.Equal(trainee.User.Id, linkedTrainee.ActiveSession.StartedByUserId);
        Assert.Equal("trainee", linkedTrainee.ActiveSession.StartedByRole);
        Assert.Equal(session.UpdatedAt, linkedTrainee.ActiveSession.UpdatedAt);
        Assert.Equal(HttpStatusCode.OK, otherResponse.StatusCode);
        Assert.NotNull(otherSummary);
        var otherLinkedTrainee = Assert.Single(otherSummary.Trainees);
        Assert.Equal(otherTrainee.User.Id, otherLinkedTrainee.Id);
        Assert.Null(otherLinkedTrainee.ActiveSession);
    }

    [Fact]
    public async Task TrainerRelationshipSummaryIncludesAssignedWorkoutSetSummaries()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var otherTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        var otherTrainee = await AuthEndpointTests.Register(client, "trainee");
        await PairTrainerAndTrainee(client, trainer, trainee);
        await PairTrainerAndTrainee(client, otherTrainer, otherTrainee);
        var assignedSet = await CreateWorkoutSet(
            client,
            trainer,
            "Push A",
            [
                new WorkoutSetRowRequest(1, 1, "Bench press", "repsWeight", 6, 40m, null),
                new WorkoutSetRowRequest(1, 2, "Bench press", "repsWeight", 6, 40m, null),
                new WorkoutSetRowRequest(2, 1, "Shoulder press", "repsWeight", 8, 22.5m, null),
            ]);
        var unassignedSet = await CreateWorkoutSet(client, trainer, "Pull B");
        var otherTrainerSet = await CreateWorkoutSet(client, otherTrainer, "Other trainer set");
        await AssignWorkoutSet(client, trainer, assignedSet.Id, [trainee.User.Id]);
        await AssignWorkoutSet(client, otherTrainer, otherTrainerSet.Id, [otherTrainee.User.Id]);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.GetAsync("/trainer/relationship");
        var summary = await response.Content.ReadFromJsonAsync<TrainerRelationshipSummaryResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(summary);
        var linkedTrainee = Assert.Single(summary.Trainees);
        var assignedSummary = Assert.Single(linkedTrainee.AssignedWorkoutSets);
        Assert.Equal(assignedSet.Id, assignedSummary.Id);
        Assert.Equal("Push A", assignedSummary.Name);
        Assert.Equal(2, assignedSummary.ExerciseCount);
        Assert.Equal(3, assignedSummary.RowCount);
        Assert.Equal(assignedSet.UpdatedAt, assignedSummary.UpdatedAt);
        Assert.DoesNotContain(
            linkedTrainee.AssignedWorkoutSets,
            set => set.Id == unassignedSet.Id || set.Id == otherTrainerSet.Id);
    }

    [Fact]
    public async Task TrainerRelationshipSummaryExcludesArchivedWorkoutSets()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairTrainerAndTrainee(client, trainer, trainee);
        var workoutSet = await CreateWorkoutSet(client, trainer, "Push A");
        await AssignWorkoutSet(client, trainer, workoutSet.Id, [trainee.User.Id]);

        using (var scope = factory.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var persisted = await dbContext.WorkoutSets.SingleAsync(set => set.Id == workoutSet.Id);
            persisted.DeletedAt = DateTimeOffset.UtcNow;
            await dbContext.SaveChangesAsync();
        }

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var summary = await client.GetFromJsonAsync<TrainerRelationshipSummaryResponse>("/trainer/relationship");

        var linkedTrainee = Assert.Single(summary!.Trainees);
        Assert.DoesNotContain(linkedTrainee.AssignedWorkoutSets, set => set.Id == workoutSet.Id);
    }

    [Fact]
    public async Task TrainerRelationshipSummaryReturnsEmptyListForNewTrainer()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.GetAsync("/trainer/relationship");
        var summary = await response.Content.ReadFromJsonAsync<TrainerRelationshipSummaryResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(summary);
        Assert.Matches(InviteCodePattern(), summary.InviteCode);
        Assert.Empty(summary.Trainees);
    }

    [Fact]
    public async Task TraineeRelationshipSummaryReturnsNullThenTrainerIdentity()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var unlinkedResponse = await client.GetAsync("/trainee/relationship");
        var unlinked = await unlinkedResponse.Content.ReadFromJsonAsync<TraineeRelationshipSummaryResponse>();

        await PairTrainerAndTrainee(client, trainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var linkedResponse = await client.GetAsync("/trainee/relationship");
        var linked = await linkedResponse.Content.ReadFromJsonAsync<TraineeRelationshipSummaryResponse>();

        Assert.Equal(HttpStatusCode.OK, unlinkedResponse.StatusCode);
        Assert.NotNull(unlinked);
        Assert.Null(unlinked.Trainer);
        Assert.Equal(HttpStatusCode.OK, linkedResponse.StatusCode);
        Assert.NotNull(linked?.Trainer);
        Assert.Equal(trainer.User.Id, linked.Trainer.Id);
        Assert.Equal(trainer.User.Email, linked.Trainer.Email);
        Assert.Equal(trainer.User.DisplayName, linked.Trainer.DisplayName);
        Assert.Equal(0, unlinked.WeeklyStreak.CurrentStreak);
        Assert.Equal(0, linked.WeeklyStreak.CurrentStreak);
    }

    [Fact]
    public async Task RelationshipSummariesBackfillCompletedHistoryForCurrentPairOnly()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var otherTrainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairTrainerAndTrainee(client, trainer, trainee);
        var completedAt = DateTimeOffset.UtcNow.AddMinutes(-5);

        using (var scope = factory.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            dbContext.SharedSessions.Add(new SharedSession
            {
                Id = Guid.NewGuid(),
                TrainerUserId = trainer.User.Id,
                TraineeUserId = trainee.User.Id,
                StartedByUserId = trainee.User.Id,
                StartedByRole = "trainee",
                Status = SharedSessionStatus.Completed,
                Version = 2,
                CreatedAt = completedAt.AddHours(-1),
                UpdatedAt = completedAt,
                ClosedAt = completedAt,
            });
            await dbContext.SaveChangesAsync();
        }

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var traineeResponse = await client.GetFromJsonAsync<TraineeRelationshipSummaryResponse>(
            "/trainee/relationship");

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var trainerResponse = await client.GetFromJsonAsync<TrainerRelationshipSummaryResponse>(
            "/trainer/relationship");

        client.DefaultRequestHeaders.Authorization = Bearer(otherTrainer.AccessToken);
        var otherTrainerResponse = await client.GetFromJsonAsync<TrainerRelationshipSummaryResponse>(
            "/trainer/relationship");

        Assert.NotNull(traineeResponse);
        Assert.Equal(1, traineeResponse.WeeklyStreak.CurrentStreak);
        Assert.Equal(completedAt, traineeResponse.WeeklyStreak.LastCompletedWorkoutAt);
        var linkedTrainee = Assert.Single(Assert.IsType<TrainerRelationshipSummaryResponse>(trainerResponse).Trainees);
        Assert.Equal(1, linkedTrainee.WeeklyStreak.CurrentStreak);
        Assert.Equal(completedAt, linkedTrainee.WeeklyStreak.LastCompletedWorkoutAt);
        Assert.Empty(Assert.IsType<TrainerRelationshipSummaryResponse>(otherTrainerResponse).Trainees);

        using var verificationScope = factory.Services.CreateScope();
        var verificationDbContext = verificationScope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.True(await verificationDbContext.TraineeWeeklyStreaks.AnyAsync(
            item => item.TraineeUserId == trainee.User.Id));
    }

    [Fact]
    public async Task InvalidCodeDoesNotChangeExistingTrainerLink()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairTrainerAndTrainee(client, trainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/trainee/trainer-link",
            new ClaimTrainerInviteCodeRequest("AAAAAA"));
        var meResponse = await client.GetAsync("/auth/me");
        var me = await meResponse.Content.ReadFromJsonAsync<AuthEndpointTests.UserResponse>();

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal(HttpStatusCode.OK, meResponse.StatusCode);
        Assert.Equal(trainer.User.Id, me?.TrainerUserId);
    }

    [Fact]
    public async Task RelationshipEndpointsRequireMatchingRole()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");

        var anonymousTrainerSummary = await client.GetAsync("/trainer/relationship");
        var anonymousTraineeSummary = await client.GetAsync("/trainee/relationship");

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var trainerAsTrainee = await client.GetAsync("/trainee/relationship");

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var traineeAsTrainer = await client.GetAsync("/trainer/relationship");

        Assert.Equal(HttpStatusCode.Unauthorized, anonymousTrainerSummary.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, anonymousTraineeSummary.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, trainerAsTrainee.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, traineeAsTrainer.StatusCode);
    }

    internal static async Task PairTrainerAndTrainee(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer,
        AuthEndpointTests.AuthResponse trainee)
    {
        var inviteCode = await GenerateTrainerInviteCode(client, trainer);

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var claimResponse = await client.PostAsJsonAsync(
            "/trainee/trainer-link",
            new ClaimTrainerInviteCodeRequest(inviteCode.Code));

        Assert.Equal(HttpStatusCode.OK, claimResponse.StatusCode);
    }

    private static async Task<TrainerInviteCodeResponse> GenerateTrainerInviteCode(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.PostAsync("/trainer/invite-code", null);
        var inviteCode = await response.Content.ReadFromJsonAsync<TrainerInviteCodeResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(inviteCode);
        return inviteCode;
    }

    private static async Task<WorkoutSetDetailResponse> CreateWorkoutSet(
        HttpClient client,
        AuthEndpointTests.AuthResponse trainer,
        string name,
        IReadOnlyList<WorkoutSetRowRequest>? rows = null)
    {
        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var response = await client.PostAsJsonAsync(
            "/workout-sets",
            new CreateWorkoutSetRequest(
                name,
                rows ?? [new WorkoutSetRowRequest(1, 1, "Bench press", "repsWeight", 6, 40m, null)]));
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

    [GeneratedRegex("^[A-HJ-NP-Z2-9]{6}$")]
    private static partial Regex InviteCodePattern();

    private sealed record TrainerInviteCodeResponse(string Code);

    private sealed record ClaimTrainerInviteCodeRequest(string Code);

    private sealed record TrainerRelationshipSummaryResponse(
        string InviteCode,
        IReadOnlyList<TrainerTraineeResponse> Trainees);

    private sealed record TrainerTraineeResponse(
        string Id,
        string Email,
        string DisplayName,
        DateTimeOffset? ConnectedAt,
        ActiveSharedSessionSummaryResponse? ActiveSession,
        IReadOnlyList<AssignedWorkoutSetSummaryResponse> AssignedWorkoutSets,
        WeeklyStreakResponse WeeklyStreak);

    private sealed record ActiveSharedSessionSummaryResponse(
        Guid SessionId,
        Guid? WorkoutSetId,
        string? WorkoutSetName,
        string StartedByUserId,
        string StartedByRole,
        DateTimeOffset UpdatedAt);

    private sealed record AssignedWorkoutSetSummaryResponse(
        Guid Id,
        string Name,
        int ExerciseCount,
        int RowCount,
        DateTimeOffset UpdatedAt);

    private sealed record TraineeRelationshipSummaryResponse(
        TraineeTrainerResponse? Trainer,
        WeeklyStreakResponse WeeklyStreak);

    private sealed record WeeklyStreakResponse(
        int CurrentStreak,
        int BestStreak,
        DateOnly? LastActiveWeekStart,
        DateTimeOffset? LastCompletedWorkoutAt,
        bool IsActiveThisWeek);

    private sealed record TraineeTrainerResponse(
        string Id,
        string Email,
        string DisplayName);

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
}
