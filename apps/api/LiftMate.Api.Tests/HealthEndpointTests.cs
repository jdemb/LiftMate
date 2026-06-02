using System.Net;
using System.Net.Http.Json;

namespace LiftMate.Api.Tests;

public sealed class HealthEndpointTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task HealthEndpointReturnsOkStatus()
    {
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/health");
        var body = await response.Content.ReadFromJsonAsync<HealthResponse>();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(body);
        Assert.Equal("ok", body.Status);
    }

    private sealed record HealthResponse(string Status);
}
