using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace LiftMate.Api.Tests.Auth;

public sealed class AuthEndpointTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task RegisterLoginMeRefreshAndLogoutUseTokenContract()
    {
        using var client = factory.CreateClient();
        var email = TestEmail();

        var registerResponse = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(email, "Pass123$Strong", "trainer", "test-invite-code"));
        var registered = await registerResponse.Content.ReadFromJsonAsync<AuthResponse>();

        Assert.Equal(HttpStatusCode.Created, registerResponse.StatusCode);
        Assert.NotNull(registered);
        Assert.NotEmpty(registered.AccessToken);
        Assert.NotEmpty(registered.RefreshToken);
        Assert.Equal(email, registered.User.Email);
        Assert.Equal("trainer", registered.User.Role);

        var loginResponse = await client.PostAsJsonAsync(
            "/auth/login",
            new LoginRequest(email, "Pass123$Strong"));
        var loggedIn = await loginResponse.Content.ReadFromJsonAsync<AuthResponse>();

        Assert.Equal(HttpStatusCode.OK, loginResponse.StatusCode);
        Assert.NotNull(loggedIn);
        Assert.NotEmpty(loggedIn.AccessToken);
        Assert.NotEmpty(loggedIn.RefreshToken);

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", loggedIn.AccessToken);
        var meResponse = await client.GetAsync("/auth/me");
        var me = await meResponse.Content.ReadFromJsonAsync<UserResponse>();

        Assert.Equal(HttpStatusCode.OK, meResponse.StatusCode);
        Assert.NotNull(me);
        Assert.Equal(email, me.Email);
        Assert.Equal("trainer", me.Role);

        var refreshResponse = await client.PostAsJsonAsync("/auth/refresh", new RefreshRequest(loggedIn.RefreshToken));
        var refreshed = await refreshResponse.Content.ReadFromJsonAsync<AuthResponse>();

        Assert.Equal(HttpStatusCode.OK, refreshResponse.StatusCode);
        Assert.NotNull(refreshed);
        Assert.NotEmpty(refreshed.AccessToken);
        Assert.NotEqual(loggedIn.RefreshToken, refreshed.RefreshToken);

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", refreshed.AccessToken);
        var logoutResponse = await client.PostAsJsonAsync("/auth/logout", new LogoutRequest(refreshed.RefreshToken));
        var repeatedLogoutResponse = await client.PostAsJsonAsync("/auth/logout", new LogoutRequest(refreshed.RefreshToken));

        Assert.Equal(HttpStatusCode.OK, logoutResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, repeatedLogoutResponse.StatusCode);
    }

    [Fact]
    public async Task RegisterRejectsInvalidInviteCode()
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(TestEmail(), "Pass123$Strong", "trainer", "wrong-code"));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task RegisterRejectsInvalidRole()
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(TestEmail(), "Pass123$Strong", "admin", "test-invite-code"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task RegisterRejectsDuplicateEmail()
    {
        using var client = factory.CreateClient();
        var email = TestEmail();
        var request = new RegisterRequest(email, "Pass123$Strong", "trainee", "test-invite-code");

        var firstResponse = await client.PostAsJsonAsync("/auth/register", request);
        var secondResponse = await client.PostAsJsonAsync("/auth/register", request);

        Assert.Equal(HttpStatusCode.Created, firstResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, secondResponse.StatusCode);
    }

    [Fact]
    public async Task MeRequiresBearerToken()
    {
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/auth/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task LogoutRequiresBearerToken()
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/auth/logout", new LogoutRequest("refresh-token"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task LogoutRejectsAnotherUsersRefreshToken()
    {
        using var client = factory.CreateClient();
        var trainer = await Register(client, "trainer");
        var trainee = await Register(client, "trainee");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", trainer.AccessToken);
        var response = await client.PostAsJsonAsync("/auth/logout", new LogoutRequest(trainee.RefreshToken));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    internal static async Task<AuthResponse> Register(HttpClient client, string role)
    {
        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(TestEmail(), "Pass123$Strong", role, "test-invite-code"));
        var auth = await response.Content.ReadFromJsonAsync<AuthResponse>();

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(auth);
        return auth;
    }

    internal static string TestEmail() => $"user-{Guid.NewGuid():N}@example.test";

    internal sealed record RegisterRequest(string Email, string Password, string Role, string InvitationCode);

    internal sealed record LoginRequest(string Email, string Password);

    internal sealed record RefreshRequest(string RefreshToken);

    internal sealed record LogoutRequest(string RefreshToken);

    internal sealed record AuthResponse(string AccessToken, string RefreshToken, DateTimeOffset ExpiresAt, UserResponse User);

    internal sealed record UserResponse(string Id, string Email, string Role);
}
