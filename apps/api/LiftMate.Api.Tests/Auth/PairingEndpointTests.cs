using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.RegularExpressions;

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
        var claimResponse = await client.PostAsJsonAsync(
            "/trainee/trainer-link",
            new ClaimTrainerInviteCodeRequest($"  {inviteCode.Code.ToLowerInvariant()}  "));
        var linked = await claimResponse.Content.ReadFromJsonAsync<AuthEndpointTests.UserResponse>();

        Assert.Equal(HttpStatusCode.OK, claimResponse.StatusCode);
        Assert.NotNull(linked);
        Assert.Equal(trainer.User.Id, linked.TrainerUserId);

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
        string DisplayName);

    private sealed record TraineeRelationshipSummaryResponse(TraineeTrainerResponse? Trainer);

    private sealed record TraineeTrainerResponse(
        string Id,
        string Email,
        string DisplayName);
}
