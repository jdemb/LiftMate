namespace LiftMate.Api.Auth;

public sealed class RegistrationGate(IConfiguration configuration)
{
    public bool Allows(string invitationCode)
    {
        var configuredCode = configuration["Auth:RegistrationInviteCode"];

        return !string.IsNullOrWhiteSpace(configuredCode)
            && string.Equals(configuredCode, invitationCode, StringComparison.Ordinal);
    }
}
