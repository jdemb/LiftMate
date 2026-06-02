namespace LiftMate.Api.Auth;

public sealed record RegisterRequest(
    string Email,
    string Password,
    string Role,
    string InvitationCode);

public sealed record LoginRequest(string Email, string Password);

public sealed record RefreshRequest(string RefreshToken);

public sealed record LogoutRequest(string RefreshToken);

public sealed record AuthResponse(
    string AccessToken,
    string RefreshToken,
    DateTimeOffset ExpiresAt,
    UserResponse User);

public sealed record UserResponse(string Id, string Email, string Role);

public sealed record ProbeResponse(string Role);
