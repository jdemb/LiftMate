using LiftMate.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.SharedSessions;

[Authorize]
public sealed class SharedSessionHub(ApplicationDbContext dbContext) : Hub
{
    public static string GroupName(Guid sessionId)
    {
        return $"shared-session:{sessionId}";
    }

    public async Task JoinSession(Guid sessionId)
    {
        var session = await dbContext.SharedSessions
            .AsNoTracking()
            .Include(session => session.TraineeUser)
            .SingleOrDefaultAsync(session => session.Id == sessionId, Context.ConnectionAborted);

        if (session is null)
        {
            throw new HubException("Shared session not found.");
        }

        if (!SharedSessionAccess.CanAccess(session, Context.User ?? throw new HubException("Unauthorized.")))
        {
            throw new HubException("Forbidden.");
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, GroupName(sessionId), Context.ConnectionAborted);
    }
}
