using Microsoft.AspNetCore.SignalR;

namespace LiftMate.Api.SharedSessions;

public sealed class SharedSessionBroadcaster(IHubContext<SharedSessionHub> hubContext)
{
    public Task BroadcastStartedAsync(SharedSession session, CancellationToken cancellationToken)
    {
        return hubContext
            .Clients
            .User(session.TraineeUserId)
            .SendAsync("sessionStarted", SharedSessionMapping.ToResponse(session), cancellationToken);
    }

    public Task BroadcastUpdatedAsync(SharedSession session, CancellationToken cancellationToken)
    {
        return hubContext
            .Clients
            .Group(SharedSessionHub.GroupName(session.Id))
            .SendAsync("sessionUpdated", SharedSessionMapping.ToResponse(session), cancellationToken);
    }
}
