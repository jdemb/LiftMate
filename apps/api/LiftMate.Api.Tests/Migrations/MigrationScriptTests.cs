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

    [Fact]
    public void PostWorkoutFeedbackMigrationGeneratesAdditiveTableWithConstraints()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlServer("Server=(localdb)\\mssqllocaldb;Database=LiftMateMigrationScript;Trusted_Connection=True")
            .Options;

        using var dbContext = new ApplicationDbContext(options);
        var migrator = dbContext.GetService<IMigrator>();
        var script = migrator.GenerateScript(
            options: MigrationsSqlGenerationOptions.Idempotent);

        Assert.Contains("AddPostWorkoutFeedback", script, StringComparison.Ordinal);
        Assert.Contains("PostWorkoutFeedbacks", script, StringComparison.Ordinal);
        Assert.Contains("SharedSessionId", script, StringComparison.Ordinal);
        Assert.Contains("WellbeingRating", script, StringComparison.Ordinal);
        Assert.Contains("SubmittedAt", script, StringComparison.Ordinal);
        Assert.Contains("CK_PostWorkoutFeedbacks_WellbeingRating", script, StringComparison.Ordinal);
        Assert.Contains("BETWEEN 1 AND 5", script, StringComparison.Ordinal);
        Assert.Contains("nvarchar(1000)", script, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("FK_PostWorkoutFeedbacks_SharedSessions_SharedSessionId", script, StringComparison.Ordinal);
    }

    [Fact]
    public void TrainerGuidanceMigrationGeneratesAdditiveTableWithDeduplicationIndex()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlServer("Server=(localdb)\\mssqllocaldb;Database=LiftMateMigrationScript;Trusted_Connection=True")
            .Options;

        using var dbContext = new ApplicationDbContext(options);
        var migrator = dbContext.GetService<IMigrator>();
        var script = migrator.GenerateScript(
            options: MigrationsSqlGenerationOptions.Idempotent);

        Assert.Contains("AddTrainerGuidance", script, StringComparison.Ordinal);
        Assert.Contains("TrainerGuidance", script, StringComparison.Ordinal);
        Assert.Contains("TraineeUserId", script, StringComparison.Ordinal);
        Assert.Contains("Fingerprint", script, StringComparison.Ordinal);
        Assert.Contains("EvidenceJson", script, StringComparison.Ordinal);
        Assert.Contains("ReadAt", script, StringComparison.Ordinal);
        Assert.Contains("CK_TrainerGuidance_Type", script, StringComparison.Ordinal);
        Assert.Contains("weight_stagnation", script, StringComparison.Ordinal);
        Assert.Contains("low_wellbeing", script, StringComparison.Ordinal);
        Assert.Contains(
            "IX_TrainerGuidance_TraineeUserId_Type_ExerciseId_Fingerprint",
            script,
            StringComparison.Ordinal);
        Assert.Contains("CREATE UNIQUE INDEX", script, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void TraineeWeeklyStreakMigrationGeneratesAdditiveTableWithConstraints()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlServer("Server=(localdb)\\mssqllocaldb;Database=LiftMateMigrationScript;Trusted_Connection=True")
            .Options;

        using var dbContext = new ApplicationDbContext(options);
        var migrator = dbContext.GetService<IMigrator>();
        var script = migrator.GenerateScript(
            options: MigrationsSqlGenerationOptions.Idempotent);

        Assert.Contains("AddTraineeWeeklyStreaks", script, StringComparison.Ordinal);
        Assert.Contains("TraineeWeeklyStreaks", script, StringComparison.Ordinal);
        Assert.Contains("LastActiveWeekStart", script, StringComparison.Ordinal);
        Assert.Contains("date", script, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("CK_TraineeWeeklyStreaks_CurrentStreak", script, StringComparison.Ordinal);
        Assert.Contains("CK_TraineeWeeklyStreaks_BestStreak", script, StringComparison.Ordinal);
        Assert.Contains("CHECK ([CurrentStreakAtLastActiveWeek] >= 0)", script, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("CHECK ([BestStreak] >= 0)", script, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void TrainerLinkedAtMigrationAddsNullableUserTimestamp()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlServer("Server=(localdb)\\mssqllocaldb;Database=LiftMateMigrationScript;Trusted_Connection=True")
            .Options;

        using var dbContext = new ApplicationDbContext(options);
        var script = dbContext.GetService<IMigrator>().GenerateScript(
            options: MigrationsSqlGenerationOptions.Idempotent);

        Assert.Contains("AddTrainerLinkedAt", script, StringComparison.Ordinal);
        Assert.Contains("TrainerLinkedAt", script, StringComparison.Ordinal);
        Assert.Contains("datetimeoffset", script, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void WorkoutSetDeletionMigrationAddsNullableTimestampAndActiveLookupIndex()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlServer("Server=(localdb)\\mssqllocaldb;Database=LiftMateMigrationScript;Trusted_Connection=True")
            .Options;

        using var dbContext = new ApplicationDbContext(options);
        var script = dbContext.GetService<IMigrator>().GenerateScript(
            options: MigrationsSqlGenerationOptions.Idempotent);

        Assert.Contains("AddWorkoutSetDeletedAt", script, StringComparison.Ordinal);
        Assert.Contains("DeletedAt", script, StringComparison.Ordinal);
        Assert.Contains("datetimeoffset", script, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("IX_WorkoutSets_TrainerUserId_DeletedAt", script, StringComparison.Ordinal);
    }
}
