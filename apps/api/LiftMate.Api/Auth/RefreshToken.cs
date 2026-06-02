namespace LiftMate.Api.Auth;

public sealed class RefreshToken
{
    public Guid Id { get; set; }

    public required string TokenHash { get; set; }

    public required string UserId { get; set; }

    public ApplicationUser? User { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset ExpiresAt { get; set; }

    public DateTimeOffset? RevokedAt { get; set; }

    public string? ReplacedByTokenHash { get; set; }
}
