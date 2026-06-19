using LiftMate.Api.Data;
using LiftMate.Api.TrainingProgress;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LiftMate.Api.Tests.TrainingProgress;

public sealed class WorkoutProgressPersistenceTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public void ProjectionModelUsesStableScalarRowKeysAndUniqueRoot()
    {
        using var scope = factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var root = dbContext.Model.FindEntityType(typeof(WorkoutProgress));
        var value = dbContext.Model.FindEntityType(typeof(WorkoutProgressValue));

        Assert.NotNull(root);
        Assert.NotNull(value);
        Assert.Contains(
            root.GetIndexes(),
            index =>
                index.IsUnique &&
                index.Properties.Select(property => property.Name)
                    .SequenceEqual([nameof(WorkoutProgress.TraineeUserId), nameof(WorkoutProgress.WorkoutSetId)]));
        Assert.Contains(
            root.GetIndexes(),
            index =>
                index.IsUnique &&
                index.Properties.Single().Name == nameof(WorkoutProgress.SourceSessionId));
        Assert.DoesNotContain(
            value.GetForeignKeys(),
            foreignKey => foreignKey.Properties.Any(
                property => property.Name == nameof(WorkoutProgressValue.WorkoutSetRowId)));
    }
}
