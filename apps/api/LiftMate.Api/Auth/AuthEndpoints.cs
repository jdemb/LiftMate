using System.Security.Claims;
using LiftMate.Api.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.Auth;

public static class AuthEndpoints
{
    public static RouteGroupBuilder MapAuthEndpoints(this IEndpointRouteBuilder routes)
    {
        var group = routes.MapGroup("/auth");

        group.MapPost("/register", Register);
        group.MapPost("/register/trainee", RegisterTrainee);
        group.MapPost("/login", Login);
        group.MapPost("/refresh", Refresh);
        group.MapPost("/logout", Logout).RequireAuthorization();
        group.MapGet("/me", Me).RequireAuthorization();

        return group;
    }

    private static async Task<IResult> Register(
        RegisterRequest request,
        UserManager<ApplicationUser> userManager,
        RegistrationGate registrationGate,
        TokenService tokenService,
        CancellationToken cancellationToken)
    {
        var gateResult = registrationGate.Evaluate(request.RegistrationInviteCode);
        if (gateResult == RegistrationGateResult.Unavailable)
        {
            return Results.Json(
                new { error = "Rejestracja jest chwilowo niedostępna. Spróbuj ponownie później." },
                statusCode: StatusCodes.Status503ServiceUnavailable);
        }

        if (gateResult == RegistrationGateResult.Invalid)
        {
            return Results.BadRequest(new { error = "Kod beta jest niepoprawny." });
        }

        var role = request.Role?.Trim().ToLowerInvariant();
        if (!UserRole.All.Contains(role, StringComparer.Ordinal))
        {
            return Results.BadRequest(new { error = "Wybierz rolę trenera lub podopiecznego." });
        }

        var email = request.Email?.Trim() ?? string.Empty;
        var existingUser = await userManager.FindByEmailAsync(email);
        if (existingUser is not null)
        {
            return Results.Conflict(new { error = "Konto z tym adresem e-mail już istnieje." });
        }

        var displayName = request.DisplayName?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(displayName))
        {
            return Results.BadRequest(new { error = "Podaj imię i nazwisko." });
        }

        var user = new ApplicationUser
        {
            Email = email,
            UserName = email,
            DisplayName = displayName,
            LiftMateRole = role!,
        };

        var result = await userManager.CreateAsync(user, request.Password ?? string.Empty);
        if (!result.Succeeded)
        {
            var message = IdentityErrorTranslator.Translate(result.Errors);
            return IdentityErrorTranslator.IsDuplicateEmail(result.Errors)
                ? Results.Conflict(new { error = message })
                : Results.BadRequest(new { error = message });
        }

        var response = await tokenService.CreateTokenPairAsync(user, cancellationToken);
        return Results.Created($"/auth/users/{user.Id}", response);
    }

    private static async Task<IResult> RegisterTrainee(
        RegisterTraineeRequest request,
        UserManager<ApplicationUser> userManager,
        ApplicationDbContext dbContext,
        RegistrationGate registrationGate,
        TokenService tokenService,
        CancellationToken cancellationToken)
    {
        var gateResult = registrationGate.Evaluate(request.RegistrationInviteCode);
        if (gateResult == RegistrationGateResult.Unavailable)
        {
            return Results.Json(
                new { error = "Rejestracja jest chwilowo niedostępna. Spróbuj ponownie później." },
                statusCode: StatusCodes.Status503ServiceUnavailable);
        }

        if (gateResult == RegistrationGateResult.Invalid)
        {
            return Results.BadRequest(new { error = "Kod beta jest niepoprawny." });
        }

        var code = NormalizeTrainerInviteCode(request.TrainerInviteCode);
        if (code is null)
        {
            return Results.NotFound(new { error = "Nie znaleziono trenera dla podanego kodu. Sprawdź kod i spróbuj ponownie." });
        }

        var inviteCode = await dbContext.TrainerInviteCodes
            .Include(value => value.TrainerUser)
            .SingleOrDefaultAsync(value => value.Code == code, cancellationToken);
        if (inviteCode?.TrainerUser is null || inviteCode.TrainerUser.LiftMateRole != UserRole.Trainer)
        {
            return Results.NotFound(new { error = "Nie znaleziono trenera dla podanego kodu. Sprawdź kod i spróbuj ponownie." });
        }

        var email = request.Email?.Trim() ?? string.Empty;
        var existingUser = await userManager.FindByEmailAsync(email);
        if (existingUser is not null)
        {
            return Results.Conflict(new { error = "Konto z tym adresem e-mail już istnieje." });
        }

        var displayName = request.DisplayName?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(displayName))
        {
            return Results.BadRequest(new { error = "Podaj imię i nazwisko." });
        }

        var linkedAt = DateTimeOffset.UtcNow;
        var user = new ApplicationUser
        {
            Email = email,
            UserName = email,
            DisplayName = displayName,
            LiftMateRole = UserRole.Trainee,
            TrainerUserId = inviteCode.TrainerUserId,
            TrainerLinkedAt = linkedAt,
        };

        var result = await userManager.CreateAsync(user, request.Password ?? string.Empty);
        if (!result.Succeeded)
        {
            var message = IdentityErrorTranslator.Translate(result.Errors);
            return IdentityErrorTranslator.IsDuplicateEmail(result.Errors)
                ? Results.Conflict(new { error = message })
                : Results.BadRequest(new { error = message });
        }

        inviteCode.LastUsedAt = linkedAt;
        await dbContext.SaveChangesAsync(cancellationToken);

        var response = await tokenService.CreateTokenPairAsync(user, cancellationToken);
        return Results.Created($"/auth/users/{user.Id}", response);
    }

    private static async Task<IResult> Login(
        LoginRequest request,
        UserManager<ApplicationUser> userManager,
        TokenService tokenService,
        CancellationToken cancellationToken)
    {
        var user = await userManager.FindByEmailAsync(request.Email.Trim());
        if (user is null || !await userManager.CheckPasswordAsync(user, request.Password))
        {
            return Results.Unauthorized();
        }

        return Results.Ok(await tokenService.CreateTokenPairAsync(user, cancellationToken));
    }

    private static async Task<IResult> Refresh(
        RefreshRequest request,
        TokenService tokenService,
        CancellationToken cancellationToken)
    {
        var response = await tokenService.RefreshAsync(request.RefreshToken, cancellationToken);
        return response is null ? Results.Unauthorized() : Results.Ok(response);
    }

    private static async Task<IResult> Logout(
        LogoutRequest request,
        ClaimsPrincipal principal,
        TokenService tokenService,
        CancellationToken cancellationToken)
    {
        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var result = await tokenService.LogoutAsync(userId, request.RefreshToken, cancellationToken);
        return result == LogoutResult.Success ? Results.Ok() : Results.Forbid();
    }

    private static async Task<IResult> Me(
        ClaimsPrincipal principal,
        UserManager<ApplicationUser> userManager)
    {
        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var user = await userManager.Users.SingleOrDefaultAsync(user => user.Id == userId);
        return user is null ? Results.Unauthorized() : Results.Ok(TokenService.ToUserResponse(user));
    }

    private static string? NormalizeTrainerInviteCode(string code)
    {
        const string inviteCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        const int inviteCodeLength = 6;

        var normalized = code.Trim().ToUpperInvariant();
        if (normalized.Length != inviteCodeLength)
        {
            return null;
        }

        return normalized.All(inviteCodeAlphabet.Contains) ? normalized : null;
    }
}
