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

        Assert.Equal(HttpStatusCode.BadRequest, invalidFormatResponse.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, notFoundResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, claimResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, reassignResponse.StatusCode);
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
}
