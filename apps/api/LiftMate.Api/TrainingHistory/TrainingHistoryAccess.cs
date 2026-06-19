using System.Security.Claims;
using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.TrainingHistory;

public static class TrainingHistoryAccess
{
    public static string? UserId(ClaimsPrincipal principal)
    {
        return principal.FindFirstValue(ClaimTypes.NameIdentifier);
    }

    public static async Task<bool> CanAccessAsync(
        ClaimsPrincipal principal,
        string targetTraineeUserId,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var userId = UserId(principal);
        if (userId is null)
        {
            return false;
        }

        if (principal.HasClaim(ClaimTypes.Role, UserRole.Trainee))
        {
            return string.Equals(userId, targetTraineeUserId, StringComparison.Ordinal);
        }

        if (!principal.HasClaim(ClaimTypes.Role, UserRole.Trainer))
        {
            return false;
        }

        return await dbContext.Users.AnyAsync(
            user =>
                user.Id == targetTraineeUserId &&
                user.LiftMateRole == UserRole.Trainee &&
                user.TrainerUserId == userId,
            cancellationToken);
    }
}
