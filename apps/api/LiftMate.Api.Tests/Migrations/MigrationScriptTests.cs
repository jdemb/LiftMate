using LiftMate.Api.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace LiftMate.Api.Tests.Migrations;

public sealed class MigrationScriptTests
{
    [Fact]
    public void StableIdentityMigrationGeneratesIdempotentBackfillsWithoutTemplateRowForeignKey()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlServer("Server=(localdb)\\mssqllocaldb;Database=LiftMateMigrationScript;Trusted_Connection=True")
            .Options;

        using var dbContext = new ApplicationDbContext(options);
        var migrator = dbContext.GetService<IMigrator>();
        var script = migrator.GenerateScript(
            options: MigrationsSqlGenerationOptions.Idempotent);

        Assert.Contains("AddStableWorkoutIdentityAndSessionSnapshots", script, StringComparison.Ordinal);
        Assert.Contains("ExerciseId", script, StringComparison.Ordinal);
        Assert.Contains("WorkoutSetRowId", script, StringComparison.Ordinal);
        Assert.Contains("WorkoutSetName", script, StringComparison.Ordinal);
        Assert.Contains("GROUP BY WorkoutSetId, ExerciseOrder", script, StringComparison.Ordinal);
        Assert.Contains("SET WorkoutSetName = workoutSet.Name", script, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "FOREIGN KEY ([WorkoutSetRowId])",
            script,
            StringComparison.OrdinalIgnoreCase);
    }
}
