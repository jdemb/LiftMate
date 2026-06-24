namespace LiftMate.Api.Auth;

public enum RegistrationGateResult
{
    Valid,
    Invalid,
    Unavailable,
}

public sealed class RegistrationGate(IConfiguration configuration)
{
    private readonly string? _expectedCode = configuration["Auth:RegistrationInviteCode"];

    public RegistrationGateResult Evaluate(string? suppliedCode)
    {
        if (string.IsNullOrWhiteSpace(_expectedCode))
        {
            return RegistrationGateResult.Unavailable;
        }

        return string.Equals(_expectedCode, suppliedCode, StringComparison.Ordinal)
            ? RegistrationGateResult.Valid
            : RegistrationGateResult.Invalid;
    }
}
