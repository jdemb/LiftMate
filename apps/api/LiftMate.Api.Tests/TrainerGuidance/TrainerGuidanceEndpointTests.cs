using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using LiftMate.Api.Tests.Auth;
using Microsoft.Extensions.DependencyInjection;

namespace LiftMate.Api.Tests.TrainerGuidance;

public sealed class TrainerGuidanceEndpointTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task CurrentTrainerListsAndMarksGuidanceAsRead()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var first = await SeedGuidance(
            trainee.User.Id,
            LiftMate.Api.TrainerGuidance.TrainerGuidanceType.WeightStagnation,
            "fingerprint-1",
            createdAtOffsetMinutes: -10,
            exerciseId: Guid.NewGuid(),
            exerciseName: "Wyciskanie sztangi",
            message: "Warto sprawdzić ciężar w ćwiczeniu Wyciskanie sztangi",
            evidenceJson: "{\"sessions\":[{\"maxWeight\":40},{\"maxWeight\":45},{\"maxWeight\":40}]}");
        var second = await SeedGuidance(
            trainee.User.Id,
            LiftMate.Api.TrainerGuidance.TrainerGuidanceType.LowWellbeing,
            "fingerprint-2",
            createdAtOffsetMinutes: -5,
            message: "Średnia ocena samopoczucia z ostatnich treningów wynosi 3.0/5",
            evidenceJson: "{\"averageRating\":3,\"sessions\":[{\"rating\":3},{\"rating\":2},{\"rating\":4}]}");
        await SeedGuidance(
            trainee.User.Id,
            LiftMate.Api.TrainerGuidance.TrainerGuidanceType.LowWellbeing,
            "already-read",
            createdAtOffsetMinutes: -1,
            read: true);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var listResponse = await client.GetAsync($"/trainer-guidance?traineeUserId={trainee.User.Id}");
        var list = await listResponse.Content.ReadFromJsonAsync<GuidanceListResponse>();

        Assert.Equal(HttpStatusCode.OK, listResponse.StatusCode);
        Assert.NotNull(list);
        Assert.Equal([second, first], list.Items.Select(item => item.Id));
        var wellbeing = list.Items[0];
        Assert.Equal(LiftMate.Api.TrainerGuidance.TrainerGuidanceType.LowWellbeing, wellbeing.Type);
        Assert.Null(wellbeing.ExerciseId);
        Assert.Contains("3.0/5", wellbeing.Message, StringComparison.Ordinal);
        Assert.Equal(3, wellbeing.Evidence.GetProperty("averageRating").GetInt32());
        var stagnation = list.Items[1];
        Assert.Equal("Wyciskanie sztangi", stagnation.ExerciseName);
        Assert.Equal(3, stagnation.Evidence.GetProperty("sessions").GetArrayLength());

        var readResponse = await client.PostAsync($"/trainer-guidance/{second}/read", null);
        var replayReadResponse = await client.PostAsync($"/trainer-guidance/{second}/read", null);
        var afterReadResponse = await client.GetAsync($"/trainer-guidance?traineeUserId={trainee.User.Id}");
        var afterRead = await afterReadResponse.Content.ReadFromJsonAsync<GuidanceListResponse>();

        Assert.Equal(HttpStatusCode.OK, readResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, replayReadResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, afterReadResponse.StatusCode);
        Assert.NotNull(afterRead);
        Assert.Equal([first], afterRead.Items.Select(item => item.Id));
    }

    [Fact]
    public async Task AccessUsesCurrentTrainerRelationshipAndTrainerRole()
    {
        using var client = factory.CreateClient();
        var trainer = await AuthEndpointTests.Register(client, "trainer");
        var newTrainer = await AuthEndpointTests.Register(client, "trainer");
        var outsider = await AuthEndpointTests.Register(client, "trainer");
        var trainee = await AuthEndpointTests.Register(client, "trainee");
        await PairingEndpointTests.PairTrainerAndTrainee(client, trainer, trainee);
        var guidanceId = await SeedGuidance(
            trainee.User.Id,
            LiftMate.Api.TrainerGuidance.TrainerGuidanceType.WeightStagnation,
            "access-fingerprint");

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var currentList = await client.GetAsync($"/trainer-guidance?traineeUserId={trainee.User.Id}");
        var currentRead = await client.PostAsync($"/trainer-guidance/{guidanceId}/read", null);

        client.DefaultRequestHeaders.Authorization = Bearer(outsider.AccessToken);
        var outsiderList = await client.GetAsync($"/trainer-guidance?traineeUserId={trainee.User.Id}");

        client.DefaultRequestHeaders.Authorization = Bearer(trainee.AccessToken);
        var traineeList = await client.GetAsync($"/trainer-guidance?traineeUserId={trainee.User.Id}");

        await PairingEndpointTests.PairTrainerAndTrainee(client, newTrainer, trainee);

        client.DefaultRequestHeaders.Authorization = Bearer(trainer.AccessToken);
        var formerList = await client.GetAsync($"/trainer-guidance?traineeUserId={trainee.User.Id}");
        var formerRead = await client.PostAsync($"/trainer-guidance/{guidanceId}/read", null);

        client.DefaultRequestHeaders.Authorization = Bearer(newTrainer.AccessToken);
        var newGuidanceId = await SeedGuidance(
            trainee.User.Id,
            LiftMate.Api.TrainerGuidance.TrainerGuidanceType.WeightStagnation,
            "new-window-fingerprint");
        var newTrainerList = await client.GetAsync($"/trainer-guidance?traineeUserId={trainee.User.Id}");
        var newTrainerBody = await newTrainerList.Content.ReadFromJsonAsync<GuidanceListResponse>();

        Assert.Equal(HttpStatusCode.OK, currentList.StatusCode);
        Assert.Equal(HttpStatusCode.OK, currentRead.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, outsiderList.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, traineeList.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, formerList.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, formerRead.StatusCode);
        Assert.Equal(HttpStatusCode.OK, newTrainerList.StatusCode);
        Assert.NotNull(newTrainerBody);
        Assert.Equal([newGuidanceId], newTrainerBody.Items.Select(item => item.Id));
    }

    private async Task<Guid> SeedGuidance(
        string traineeUserId,
        string type,
        string fingerprint,
        int createdAtOffsetMinutes = 0,
        Guid? exerciseId = null,
        string? exerciseName = null,
        string message = "Warto sprawdzić ciężar w ćwiczeniu Bench",
        string evidenceJson = "{\"sessions\":[]}",
        bool read = false)
    {
        var guidance = new LiftMate.Api.TrainerGuidance.TrainerGuidance
        {
            Id = Guid.NewGuid(),
            TraineeUserId = traineeUserId,
            Type = type,
            ExerciseId = exerciseId,
            ExerciseName = exerciseName,
            Fingerprint = fingerprint,
            Message = message,
            EvidenceJson = evidenceJson,
            CreatedAt = DateTimeOffset.UtcNow.AddMinutes(createdAtOffsetMinutes),
            ReadAt = read ? DateTimeOffset.UtcNow : null,
        };

        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        dbContext.TrainerGuidance.Add(guidance);
        await dbContext.SaveChangesAsync();
        return guidance.Id;
    }

    private static AuthenticationHeaderValue Bearer(string accessToken)
    {
        return new AuthenticationHeaderValue("Bearer", accessToken);
    }

    private sealed record GuidanceListResponse(IReadOnlyList<GuidanceResponse> Items);

    private sealed record GuidanceResponse(
        Guid Id,
        string Type,
        string TraineeUserId,
        Guid? ExerciseId,
        string? ExerciseName,
        string Message,
        System.Text.Json.JsonElement Evidence,
        DateTimeOffset CreatedAt);
}
