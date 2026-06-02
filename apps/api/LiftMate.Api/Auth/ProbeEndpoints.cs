namespace LiftMate.Api.Auth;

public static class ProbeEndpoints
{
    public static IEndpointRouteBuilder MapProbeEndpoints(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/trainer/probe", () => Results.Ok(new ProbeResponse(UserRole.Trainer)))
            .RequireAuthorization("TrainerOnly");

        routes.MapGet("/trainee/probe", () => Results.Ok(new ProbeResponse(UserRole.Trainee)))
            .RequireAuthorization("TraineeOnly");

        return routes;
    }
}
