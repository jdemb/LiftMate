using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace LiftMate.Api.Tests.Auth;

public sealed class RoleProbeTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task TrainerTokenCanAccessTrainerProbeOnly()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", trainer.AccessToken);

        var trainerProbe = await client.GetAsync("/trainer/probe");
        var trainerBody = await trainerProbe.Content.ReadFromJsonAsync<ProbeResponse>();
        var traineeProbe = await client.GetAsync("/trainee/probe");

        Assert.Equal(HttpStatusCode.OK, trainerProbe.StatusCode);
        Assert.NotNull(trainerBody);
        Assert.Equal("trainer", trainerBody.Role);
        Assert.Equal(HttpStatusCode.Forbidden, traineeProbe.StatusCode);
    }

    [Fact]
    public async Task TraineeTokenCanAccessTraineeProbeOnly()
    {
        using var client = factory.CreateClient();
        var trainee = await AuthEndpointTests.Register(client, "trainee");

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", trainee.AccessToken);

        var traineeProbe = await client.GetAsync("/trainee/probe");
        var traineeBody = await traineeProbe.Content.ReadFromJsonAsync<ProbeResponse>();
        var trainerProbe = await client.GetAsync("/trainer/probe");

        Assert.Equal(HttpStatusCode.OK, traineeProbe.StatusCode);
        Assert.NotNull(traineeBody);
        Assert.Equal("trainee", traineeBody.Role);
        Assert.Equal(HttpStatusCode.Forbidden, trainerProbe.StatusCode);
    }

    private sealed record ProbeResponse(string Role);
}
