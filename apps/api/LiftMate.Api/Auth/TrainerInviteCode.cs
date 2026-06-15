namespace LiftMate.Api.Auth;

public sealed class TrainerInviteCode
{
    public Guid Id { get; set; }

    public string Code { get; set; } = string.Empty;

    public string TrainerUserId { get; set; } = string.Empty;

    public ApplicationUser? TrainerUser { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? LastUsedAt { get; set; }
}
