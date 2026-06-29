using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LiftMate.Api.Tests.Auth;

public sealed class AuthEndpointTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    internal const string TestRegistrationInviteCode = "Beta-Access-2026";

    [Fact]
    public async Task RegisterLoginMeRefreshAndLogoutUseTokenContract()
    {
        using var client = factory.CreateClient();
        var email = TestEmail();

        var registerResponse = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(
                email,
                "Pass123$Strong",
                "trainer",
                "Test Trainer",
                TestRegistrationInviteCode));
        var registered = await registerResponse.Content.ReadFromJsonAsync<AuthResponse>();

        Assert.Equal(HttpStatusCode.Created, registerResponse.StatusCode);
        Assert.NotNull(registered);
        Assert.NotEmpty(registered.AccessToken);
        Assert.NotEmpty(registered.RefreshToken);
        Assert.Equal(email, registered.User.Email);
        Assert.Equal("trainer", registered.User.Role);
        Assert.Equal("Test Trainer", registered.User.DisplayName);
        Assert.Null(registered.User.TrainerUserId);

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
        Assert.Equal("Test Trainer", me.DisplayName);
        Assert.Null(me.TrainerUserId);

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

    [Theory]
    [InlineData("trainer", "Test Trainer")]
    [InlineData("trainee", "Test Trainee")]
    public async Task RegisterAcceptsConfiguredInviteCodeForBothRoles(string role, string displayName)
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(
                TestEmail(),
                "Pass123$Strong",
                role,
                displayName,
                TestRegistrationInviteCode));

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    [Fact]
    public async Task RegisterTraineeWithTrainerCodeCreatesLinkedAccount()
    {
        using var client = factory.CreateClient();
        var trainer = await Register(client, "trainer");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", trainer.AccessToken);
        var inviteResponse = await client.PostAsync("/trainer/invite-code", null);
        var invite = await inviteResponse.Content.ReadFromJsonAsync<TrainerInviteCodeResponse>();
        client.DefaultRequestHeaders.Authorization = null;
        var email = TestEmail();

        var startedAt = DateTimeOffset.UtcNow;
        var response = await client.PostAsJsonAsync(
            "/auth/register/trainee",
            new RegisterTraineeRequest(
                email,
                "Pass123$Strong",
                "Test Trainee",
                TestRegistrationInviteCode,
                invite!.Code.ToLowerInvariant()));
        var completedAt = DateTimeOffset.UtcNow;
        var registered = await response.Content.ReadFromJsonAsync<AuthResponse>();

        using var scope = factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var persisted = await dbContext.Users.SingleAsync(user => user.Email == email);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(registered);
        Assert.Equal(email, registered.User.Email);
        Assert.Equal("trainee", registered.User.Role);
        Assert.Equal(trainer.User.Id, registered.User.TrainerUserId);
        Assert.NotNull(persisted.TrainerLinkedAt);
        Assert.InRange(persisted.TrainerLinkedAt.Value, startedAt, completedAt);
    }

    [Fact]
    public async Task RegisterTraineeWithInvalidTrainerCodeDoesNotCreateUser()
    {
        using var client = factory.CreateClient();
        var email = TestEmail();

        var response = await client.PostAsJsonAsync(
            "/auth/register/trainee",
            new RegisterTraineeRequest(
                email,
                "Pass123$Strong",
                "Test Trainee",
                TestRegistrationInviteCode,
                "WRONG1"));
        var error = await ReadSingleError(response);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("Nie znaleziono trenera dla podanego kodu. Sprawdź kod i spróbuj ponownie.", error);

        var loginResponse = await client.PostAsJsonAsync(
            "/auth/login",
            new LoginRequest(email, "Pass123$Strong"));
        Assert.Equal(HttpStatusCode.Unauthorized, loginResponse.StatusCode);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("wrong-code")]
    [InlineData("beta-access-2026")]
    [InlineData(" Beta-Access-2026")]
    public async Task RegisterRejectsMissingOrNonMatchingInviteCodeWithoutCreatingUser(string? inviteCode)
    {
        using var client = factory.CreateClient();
        var email = TestEmail();

        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(email, "Pass123$Strong", "trainer", "Test Trainer", inviteCode));
        var error = await ReadSingleError(response);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("Kod beta jest niepoprawny.", error);

        var loginResponse = await client.PostAsJsonAsync(
            "/auth/login",
            new LoginRequest(email, "Pass123$Strong"));
        Assert.Equal(HttpStatusCode.Unauthorized, loginResponse.StatusCode);
    }

    [Fact]
    public async Task RegisterReturnsFriendlyUnavailableErrorWhenInviteCodeIsNotConfiguredAndLoginStillWorks()
    {
        await using var factoryWithoutInviteCode = new TestApplicationFactory(string.Empty);
        using var scope = factoryWithoutInviteCode.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var email = TestEmail();
        var user = new ApplicationUser
        {
            Email = email,
            UserName = email,
            DisplayName = "Existing Trainer",
            LiftMateRole = UserRole.Trainer,
        };
        var createResult = await userManager.CreateAsync(user, "Pass123$Strong");
        Assert.True(createResult.Succeeded);

        using var client = factoryWithoutInviteCode.CreateClient();
        var registerResponse = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(
                TestEmail(),
                "Pass123$Strong",
                "trainer",
                "New Trainer",
                TestRegistrationInviteCode));
        var error = await ReadSingleError(registerResponse);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, registerResponse.StatusCode);
        Assert.Equal("Rejestracja jest chwilowo niedostępna. Spróbuj ponownie później.", error);

        var loginResponse = await client.PostAsJsonAsync(
            "/auth/login",
            new LoginRequest(email, "Pass123$Strong"));
        Assert.Equal(HttpStatusCode.OK, loginResponse.StatusCode);
    }

    [Fact]
    public async Task InviteCodeIsCheckedBeforeDuplicateEmail()
    {
        using var client = factory.CreateClient();
        var registered = await Register(client, "trainer");

        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(
                registered.User.Email,
                "Pass123$Strong",
                "trainer",
                "Test Trainer",
                "wrong-code"));
        var error = await ReadSingleError(response);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("Kod beta jest niepoprawny.", error);
    }

    [Fact]
    public async Task RegisterRejectsInvalidRole()
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(
                TestEmail(),
                "Pass123$Strong",
                "admin",
                "Test Trainer",
                TestRegistrationInviteCode));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("Wybierz rolę trenera lub podopiecznego.", await ReadSingleError(response));
    }

    [Fact]
    public async Task RegisterRejectsBlankDisplayName()
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(
                TestEmail(),
                "Pass123$Strong",
                "trainer",
                "   ",
                TestRegistrationInviteCode));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("Podaj imię i nazwisko.", await ReadSingleError(response));
    }

    [Fact]
    public async Task RegisterRejectsDuplicateEmail()
    {
        using var client = factory.CreateClient();
        var email = TestEmail();
        var request = new RegisterRequest(
            email,
            "Pass123$Strong",
            "trainee",
            "Test Trainee",
            TestRegistrationInviteCode);

        var firstResponse = await client.PostAsJsonAsync("/auth/register", request);
        var secondResponse = await client.PostAsJsonAsync("/auth/register", request);

        Assert.Equal(HttpStatusCode.Created, firstResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, secondResponse.StatusCode);
        Assert.Equal(
            "Konto z tym adresem e-mail już istnieje.",
            await ReadSingleError(secondResponse));
    }

    [Fact]
    public async Task RegisterRejectsInvalidEmailWithPolishSingleError()
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(
                "not-an-email",
                "Pass123$Strong",
                "trainer",
                "Test Trainer",
                TestRegistrationInviteCode));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("Podaj poprawny adres e-mail.", await ReadSingleError(response));
    }

    [Fact]
    public async Task RegisterRejectsWeakPasswordWithoutIdentityDetails()
    {
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(
                TestEmail(),
                "weak",
                "trainer",
                "Test Trainer",
                TestRegistrationInviteCode));
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("Hasło nie spełnia wymagań bezpieczeństwa.", await ReadSingleError(response));
        Assert.DoesNotContain("PasswordTooShort", body, StringComparison.Ordinal);
        Assert.DoesNotContain("Passwords must", body, StringComparison.Ordinal);
        Assert.DoesNotContain("errors", body, StringComparison.Ordinal);
    }

    [Fact]
    public void IdentityErrorTranslatorUsesNeutralFallbackForUnknownCode()
    {
        var message = IdentityErrorTranslator.Translate(
            [new IdentityError { Code = "UnexpectedIdentityFailure", Description = "Technical details." }]);

        Assert.Equal("Nie udało się utworzyć konta. Spróbuj ponownie.", message);
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
        var displayName = role == "trainer" ? "Test Trainer" : "Test Trainee";
        var response = await client.PostAsJsonAsync(
            "/auth/register",
            new RegisterRequest(
                TestEmail(),
                "Pass123$Strong",
                role,
                displayName,
                TestRegistrationInviteCode));
        var auth = await response.Content.ReadFromJsonAsync<AuthResponse>();

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(auth);
        return auth;
    }

    internal static string TestEmail() => $"user-{Guid.NewGuid():N}@example.test";

    private static async Task<string> ReadSingleError(HttpResponseMessage response)
    {
        var payload = await response.Content.ReadFromJsonAsync<Dictionary<string, string>>();
        Assert.NotNull(payload);
        var error = Assert.Single(payload);
        Assert.Equal("error", error.Key);
        return error.Value;
    }

    internal sealed record RegisterRequest(
        string Email,
        string Password,
        string Role,
        string DisplayName,
        string? RegistrationInviteCode);

    internal sealed record RegisterTraineeRequest(
        string Email,
        string Password,
        string DisplayName,
        string? RegistrationInviteCode,
        string TrainerInviteCode);

    internal sealed record LoginRequest(string Email, string Password);

    internal sealed record RefreshRequest(string RefreshToken);

    internal sealed record LogoutRequest(string RefreshToken);

    internal sealed record AuthResponse(string AccessToken, string RefreshToken, DateTimeOffset ExpiresAt, UserResponse User);

    internal sealed record UserResponse(string Id, string Email, string Role, string DisplayName, string? TrainerUserId);
}
