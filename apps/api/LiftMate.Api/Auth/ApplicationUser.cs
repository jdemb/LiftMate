using Microsoft.AspNetCore.Identity;

namespace LiftMate.Api.Auth;

public sealed class ApplicationUser : IdentityUser
{
    public string LiftMateRole { get; set; } = string.Empty;

    public ICollection<RefreshToken> RefreshTokens { get; } = new List<RefreshToken>();
}
