using System.Security.Claims;

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
}
