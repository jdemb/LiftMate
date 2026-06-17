using Microsoft.AspNetCore.SignalR;

namespace LiftMate.Api.SharedSessions;

public sealed class SharedSessionBroadcaster(IHubContext<SharedSessionHub> hubContext)
{
    public Task BroadcastStartedAsync(SharedSession session, CancellationToken cancellationToken)
    {
        var response = SharedSessionMapping.ToResponse(session);
        var traineeTask = hubContext
            .Clients
            .User(session.TraineeUserId)
            .SendAsync("sessionStarted", response, cancellationToken);
        var trainerTask = hubContext
            .Clients
            .User(session.TrainerUserId)
            .SendAsync("sessionStarted", response, cancellationToken);

        return Task.WhenAll(traineeTask, trainerTask);
    }

    public Task BroadcastUpdatedAsync(SharedSession session, CancellationToken cancellationToken)
    {
        return hubContext
            .Clients
            .Group(SharedSessionHub.GroupName(session.Id))
            .SendAsync("sessionUpdated", SharedSessionMapping.ToResponse(session), cancellationToken);
    }
}
