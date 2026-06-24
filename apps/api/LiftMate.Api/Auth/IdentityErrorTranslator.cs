using Microsoft.AspNetCore.Identity;

namespace LiftMate.Api.Auth;

public static class IdentityErrorTranslator
{
    private const string DuplicateEmailCode = "DuplicateEmail";
    private const string DuplicateUserNameCode = "DuplicateUserName";
    private const string InvalidEmailCode = "InvalidEmail";
    private const string InvalidUserNameCode = "InvalidUserName";

    public static string Translate(IEnumerable<IdentityError> errors)
    {
        var codes = errors.Select(error => error.Code).ToArray();

        if (codes.Contains(InvalidEmailCode, StringComparer.Ordinal) ||
            codes.Contains(InvalidUserNameCode, StringComparer.Ordinal))
        {
            return "Podaj poprawny adres e-mail.";
        }

        if (codes.Any(code => code.StartsWith("Password", StringComparison.Ordinal)))
        {
            return "Hasło nie spełnia wymagań bezpieczeństwa.";
        }

        if (codes.Contains(DuplicateEmailCode, StringComparer.Ordinal) ||
            codes.Contains(DuplicateUserNameCode, StringComparer.Ordinal))
        {
            return "Konto z tym adresem e-mail już istnieje.";
        }

        return "Nie udało się utworzyć konta. Spróbuj ponownie.";
    }

    public static bool IsDuplicateEmail(IEnumerable<IdentityError> errors)
    {
        return errors.Any(error =>
            string.Equals(error.Code, DuplicateEmailCode, StringComparison.Ordinal) ||
            string.Equals(error.Code, DuplicateUserNameCode, StringComparison.Ordinal));
    }
}
