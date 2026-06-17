using System.Security.Claims;
using LiftMate.Api.Auth;

namespace LiftMate.Api.SharedSessions;

public static class SharedSessionAccess
{
    public static string? UserId(ClaimsPrincipal principal)
    {
        return principal.FindFirstValue(ClaimTypes.NameIdentifier);
    }

    public static bool IsParticipant(SharedSession session, ClaimsPrincipal principal)
    {
        var userId = UserId(principal);
        return userId is not null && IsParticipant(session, userId);
    }

    public static bool IsParticipant(SharedSession session, string userId)
    {
        return string.Equals(session.TrainerUserId, userId, StringComparison.Ordinal) ||
            string.Equals(session.TraineeUserId, userId, StringComparison.Ordinal);
    }

    public static bool CanAccess(SharedSession session, ClaimsPrincipal principal)
    {
        var userId = UserId(principal);
        return userId is not null && CanAccess(session, principal, userId);
    }

    public static bool CanAccess(SharedSession session, ClaimsPrincipal principal, string userId)
    {
        if (string.Equals(session.TraineeUserId, userId, StringComparison.Ordinal))
        {
            return true;
        }

        if (!string.Equals(session.TrainerUserId, userId, StringComparison.Ordinal))
        {
            return false;
        }

        if (!principal.HasClaim(ClaimTypes.Role, UserRole.Trainer))
        {
            return false;
        }

        return string.Equals(session.TraineeUser?.TrainerUserId, userId, StringComparison.Ordinal);
    }
}
