using System.Security.Claims;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.Auth;

public static class AuthEndpoints
{
    public static RouteGroupBuilder MapAuthEndpoints(this IEndpointRouteBuilder routes)
    {
        var group = routes.MapGroup("/auth");

        group.MapPost("/register", Register);
        group.MapPost("/login", Login);
        group.MapPost("/refresh", Refresh);
        group.MapPost("/logout", Logout).RequireAuthorization();
        group.MapGet("/me", Me).RequireAuthorization();

        return group;
    }

    private static async Task<IResult> Register(
        RegisterRequest request,
        RegistrationGate registrationGate,
        UserManager<ApplicationUser> userManager,
        TokenService tokenService,
        CancellationToken cancellationToken)
    {
        var role = request.Role.Trim().ToLowerInvariant();
        if (!UserRole.All.Contains(role, StringComparer.Ordinal))
        {
            return Results.BadRequest(new { error = "Invalid role." });
        }

        if (!registrationGate.Allows(request.InvitationCode))
        {
            return Results.Forbid();
        }

        var email = request.Email.Trim();
        var existingUser = await userManager.FindByEmailAsync(email);
        if (existingUser is not null)
        {
            return Results.Conflict(new { error = "Email already registered." });
        }

        var displayName = request.DisplayName.Trim();
        if (string.IsNullOrWhiteSpace(displayName))
        {
            return Results.BadRequest(new { error = "Display name is required." });
        }

        var user = new ApplicationUser
        {
            Email = email,
            UserName = email,
            DisplayName = displayName,
            LiftMateRole = role,
        };

        var result = await userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
        {
            return Results.BadRequest(new { errors = result.Errors.Select(error => error.Description) });
        }

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
}
