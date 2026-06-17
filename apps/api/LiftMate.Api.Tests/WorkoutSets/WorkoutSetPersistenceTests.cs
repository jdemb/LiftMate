using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using LiftMate.Api.WorkoutSets;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LiftMate.Api.Tests.WorkoutSets;

public sealed class WorkoutSetPersistenceTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task WorkoutSetPersistsRowsAndAssignments()
    {
        using var scope = factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var idPrefix = Guid.NewGuid().ToString("N");
        var trainer = CreateUser($"{idPrefix}-trainer", UserRole.Trainer);
        var trainee = CreateUser($"{idPrefix}-trainee", UserRole.Trainee, trainer.Id);
        var now = DateTimeOffset.UtcNow;
        var workoutSet = new WorkoutSet
        {
            Id = Guid.NewGuid(),
            TrainerUserId = trainer.Id,
            Name = "Push A",
            CreatedAt = now,
            UpdatedAt = now,
        };

        workoutSet.Rows.Add(new WorkoutSetRow
        {
            Id = Guid.NewGuid(),
            ExerciseOrder = 1,
            SetIndex = 1,
            ExerciseName = "Bench press",
            ExerciseType = ExerciseValueType.RepsWeight,
            Reps = 6,
            Weight = 80.5m,
        });
        workoutSet.Assignments.Add(new WorkoutSetAssignment
        {
            Id = Guid.NewGuid(),
            TraineeUserId = trainee.Id,
            AssignedByTrainerUserId = trainer.Id,
            AssignedAt = now,
        });

        dbContext.Users.AddRange(trainer, trainee);
        dbContext.WorkoutSets.Add(workoutSet);
        await dbContext.SaveChangesAsync();

        dbContext.ChangeTracker.Clear();

        var saved = await dbContext.WorkoutSets
            .Include(set => set.Rows)
            .Include(set => set.Assignments)
            .SingleAsync(set => set.Id == workoutSet.Id);

        Assert.Equal(trainer.Id, saved.TrainerUserId);
        Assert.Equal("Push A", saved.Name);
        var row = Assert.Single(saved.Rows);
        Assert.Equal(1, row.ExerciseOrder);
        Assert.Equal(1, row.SetIndex);
        Assert.Equal("Bench press", row.ExerciseName);
        Assert.Equal(ExerciseValueType.RepsWeight, row.ExerciseType);
        Assert.Equal(6, row.Reps);
        Assert.Equal(80.5m, row.Weight);
        var assignment = Assert.Single(saved.Assignments);
        Assert.Equal(trainee.Id, assignment.TraineeUserId);
        Assert.Equal(trainer.Id, assignment.AssignedByTrainerUserId);
    }

    [Theory]
    [InlineData(ExerciseValueType.RepsWeight, 8, 42.5, null)]
    [InlineData(ExerciseValueType.RepsOnly, 12, null, null)]
    [InlineData(ExerciseValueType.Time, null, null, 45)]
    public void ValidateRowAcceptsExpectedExerciseTypeMatrix(
        string exerciseType,
        int? reps,
        double? weight,
        int? seconds)
    {
        var error = WorkoutSetValidation.ValidateRow(
            exerciseOrder: 1,
            setIndex: 1,
            exerciseName: "Squat",
            exerciseType,
            reps,
            weight is null ? null : Convert.ToDecimal(weight),
            seconds);

        Assert.Null(error);
    }

    [Theory]
    [InlineData(0, 1, "Squat", ExerciseValueType.RepsWeight, 8, 42.5, null)]
    [InlineData(1, 0, "Squat", ExerciseValueType.RepsWeight, 8, 42.5, null)]
    [InlineData(1, 1, "", ExerciseValueType.RepsWeight, 8, 42.5, null)]
    [InlineData(1, 1, "Squat", "distance", 8, 42.5, null)]
    [InlineData(1, 1, "Squat", ExerciseValueType.RepsWeight, null, 42.5, null)]
    [InlineData(1, 1, "Squat", ExerciseValueType.RepsWeight, 8, 42.5, 30)]
    [InlineData(1, 1, "Squat", ExerciseValueType.RepsOnly, 8, 42.5, null)]
    [InlineData(1, 1, "Squat", ExerciseValueType.Time, 8, null, 30)]
    public void ValidateRowRejectsInvalidRows(
        int exerciseOrder,
        int setIndex,
        string exerciseName,
        string exerciseType,
        int? reps,
        double? weight,
        int? seconds)
    {
        var error = WorkoutSetValidation.ValidateRow(
            exerciseOrder,
            setIndex,
            exerciseName,
            exerciseType,
            reps,
            weight is null ? null : Convert.ToDecimal(weight),
            seconds);

        Assert.NotNull(error);
    }

    [Fact]
    public void ValidateSetNameRejectsBlankName()
    {
        Assert.NotNull(WorkoutSetValidation.ValidateSetName(" "));
        Assert.Null(WorkoutSetValidation.ValidateSetName("Leg day"));
    }

    private static ApplicationUser CreateUser(string handle, string role, string? trainerUserId = null)
    {
        return new ApplicationUser
        {
            Id = Guid.NewGuid().ToString(),
            UserName = $"{handle}@example.test",
            NormalizedUserName = $"{handle}@example.test".ToUpperInvariant(),
            Email = $"{handle}@example.test",
            NormalizedEmail = $"{handle}@example.test".ToUpperInvariant(),
            EmailConfirmed = true,
            DisplayName = handle,
            LiftMateRole = role,
            TrainerUserId = trainerUserId,
        };
    }
}
