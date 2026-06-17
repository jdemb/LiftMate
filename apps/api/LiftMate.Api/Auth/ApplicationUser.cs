using Microsoft.AspNetCore.Identity;

namespace LiftMate.Api.Auth;

public sealed class ApplicationUser : IdentityUser
{
    public string DisplayName { get; set; } = string.Empty;

    public string LiftMateRole { get; set; } = string.Empty;

    public string? TrainerUserId { get; set; }

    public ApplicationUser? TrainerUser { get; set; }

    public ICollection<ApplicationUser> Trainees { get; } = new List<ApplicationUser>();

    public ICollection<RefreshToken> RefreshTokens { get; } = new List<RefreshToken>();
}
