using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using LiftMate.Api.SharedSessions;
using LiftMate.Api.TrainerGuidance;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace LiftMate.Api.Tests.TrainerGuidance;

public sealed class TrainerGuidanceEvaluatorTests(TestApplicationFactory factory)
    : IClassFixture<TestApplicationFactory>
{
    [Fact]
    public async Task WeightStagnationRequiresThreeCompletedRepsWeightSessionsWithStableExerciseId()
    {
        var trainerId = $"trainer-{Guid.NewGuid():N}";
        var traineeId = $"trainee-{Guid.NewGuid():N}";
        var exerciseId = Guid.NewGuid();
        await SeedSessions([
            CompletedSession(trainerId, traineeId, exerciseId, ExerciseValueType.RepsWeight, "Bench press", 40m, -3),
            CompletedSession(trainerId, traineeId, exerciseId, ExerciseValueType.RepsWeight, "Bench press renamed", 45m, -2),
        ]);

        await EvaluateWeightStagnation(traineeId);

        Assert.Empty(await ReadGuidance(traineeId));

        await SeedSessions([
            CompletedSession(trainerId, traineeId, exerciseId, ExerciseValueType.RepsWeight, "Bench press reordered", 40m, -1),
            CompletedSession(trainerId, traineeId, null, ExerciseValueType.RepsWeight, "No id", 10m, 0),
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsOnly, "Push ups", null, 1, reps: 20),
        ]);

        await EvaluateWeightStagnation(traineeId);

        var guidance = Assert.Single(await ReadGuidance(traineeId));
        Assert.Equal(TrainerGuidanceType.WeightStagnation, guidance.Type);
        Assert.Equal(exerciseId, guidance.ExerciseId);
        Assert.Equal("Bench press reordered", guidance.ExerciseName);
        Assert.Contains("Warto sprawdzić ciężar", guidance.Message, StringComparison.Ordinal);
        Assert.Contains("40", guidance.EvidenceJson, StringComparison.Ordinal);
        Assert.Contains("45", guidance.EvidenceJson, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(40, 45, 40, true)]
    [InlineData(40, 35, 40, true)]
    [InlineData(40, 35, 42.5, false)]
    public async Task WeightStagnationUsesNewestComparedWithOldestWeightWindow(
        decimal oldest,
        decimal middle,
        decimal newest,
        bool shouldCreate)
    {
        var trainerId = $"trainer-{Guid.NewGuid():N}";
        var traineeId = $"trainee-{Guid.NewGuid():N}";
        var exerciseId = Guid.NewGuid();
        await SeedSessions([
            CompletedSession(trainerId, traineeId, exerciseId, ExerciseValueType.RepsWeight, "Bench", oldest, -3),
            CompletedSession(trainerId, traineeId, exerciseId, ExerciseValueType.RepsWeight, "Bench", middle, -2),
            CompletedSession(trainerId, traineeId, exerciseId, ExerciseValueType.RepsWeight, "Bench", newest, -1),
        ]);

        await EvaluateWeightStagnation(traineeId);

        var guidance = await ReadGuidance(traineeId);
        Assert.Equal(shouldCreate ? 1 : 0, guidance.Count);
    }

    [Fact]
    public async Task WeightStagnationDoesNotMergeSameExerciseNameAcrossDifferentExerciseIds()
    {
        var trainerId = $"trainer-{Guid.NewGuid():N}";
        var traineeId = $"trainee-{Guid.NewGuid():N}";
        await SeedSessions([
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 40m, -3),
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 45m, -2),
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 40m, -1),
        ]);

        await EvaluateWeightStagnation(traineeId);

        Assert.Empty(await ReadGuidance(traineeId));
    }

    [Fact]
    public async Task WellbeingUsesThreeLatestFeedbackSessionsIgnoresCommentsAndSkipsMissingFeedback()
    {
        var trainerId = $"trainer-{Guid.NewGuid():N}";
        var traineeId = $"trainee-{Guid.NewGuid():N}";
        await SeedSessions([
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 40m, -5, feedbackRating: 5, feedbackComment: "ignored high old"),
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 40m, -4),
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 40m, -3, feedbackRating: 3, feedbackComment: "bad"),
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 40m, -2, feedbackRating: 2, feedbackComment: "great"),
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 40m, -1, feedbackRating: 4, feedbackComment: "neutral"),
        ]);

        await EvaluateLowWellbeing(traineeId);

        var guidance = Assert.Single(await ReadGuidance(traineeId));
        Assert.Equal(TrainerGuidanceType.LowWellbeing, guidance.Type);
        Assert.Null(guidance.ExerciseId);
        Assert.Contains("3.0/5", guidance.Message, StringComparison.Ordinal);
        Assert.Contains("\"averageRating\":3", guidance.EvidenceJson, StringComparison.Ordinal);
        Assert.DoesNotContain("bad", guidance.EvidenceJson, StringComparison.Ordinal);
        Assert.DoesNotContain("great", guidance.EvidenceJson, StringComparison.Ordinal);
    }

    [Fact]
    public async Task WellbeingDoesNotCreateSignalWhenLatestFeedbackAverageIsAboveThree()
    {
        var trainerId = $"trainer-{Guid.NewGuid():N}";
        var traineeId = $"trainee-{Guid.NewGuid():N}";
        await SeedSessions([
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 40m, -3, feedbackRating: 4),
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 40m, -2, feedbackRating: 4),
            CompletedSession(trainerId, traineeId, Guid.NewGuid(), ExerciseValueType.RepsWeight, "Bench", 40m, -1, feedbackRating: 3),
        ]);

        await EvaluateLowWellbeing(traineeId);

        Assert.Empty(await ReadGuidance(traineeId));
    }

    [Fact]
    public async Task ReEvaluationAndReplayDoNotCreateDuplicateGuidance()
    {
        var trainerId = $"trainer-{Guid.NewGuid():N}";
        var traineeId = $"trainee-{Guid.NewGuid():N}";
        var exerciseId = Guid.NewGuid();
        await SeedSessions([
            CompletedSession(trainerId, traineeId, exerciseId, ExerciseValueType.RepsWeight, "Bench", 40m, -3, feedbackRating: 3),
            CompletedSession(trainerId, traineeId, exerciseId, ExerciseValueType.RepsWeight, "Bench", 45m, -2, feedbackRating: 2),
            CompletedSession(trainerId, traineeId, exerciseId, ExerciseValueType.RepsWeight, "Bench", 40m, -1, feedbackRating: 4),
        ]);

        await EvaluateWeightStagnation(traineeId);
        await EvaluateWeightStagnation(traineeId);
        await EvaluateLowWellbeing(traineeId);
        await EvaluateLowWellbeing(traineeId);

        var guidance = await ReadGuidance(traineeId);
        Assert.Equal(2, guidance.Count);
        Assert.Equal(1, guidance.Count(item => item.Type == TrainerGuidanceType.WeightStagnation));
        Assert.Equal(1, guidance.Count(item => item.Type == TrainerGuidanceType.LowWellbeing));
    }

    private async Task EvaluateWeightStagnation(string traineeUserId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var evaluator = scope.ServiceProvider.GetRequiredService<TrainerGuidanceEvaluator>();
        await evaluator.EvaluateWeightStagnationAsync(traineeUserId, CancellationToken.None);
    }

    private async Task EvaluateLowWellbeing(string traineeUserId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var evaluator = scope.ServiceProvider.GetRequiredService<TrainerGuidanceEvaluator>();
        await evaluator.EvaluateLowWellbeingAsync(traineeUserId, CancellationToken.None);
    }

    private async Task<IReadOnlyList<LiftMate.Api.TrainerGuidance.TrainerGuidance>> ReadGuidance(string traineeUserId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        return await dbContext.TrainerGuidance
            .Where(item => item.TraineeUserId == traineeUserId)
            .OrderBy(item => item.Type)
            .ToListAsync();
    }

    private async Task SeedSessions(IEnumerable<SharedSession> sessions)
    {
        var materialized = sessions.ToArray();
        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        foreach (var pair in materialized
            .Select(session => new { session.TrainerUserId, session.TraineeUserId })
            .Distinct())
        {
            if (!await dbContext.Users.AnyAsync(user => user.Id == pair.TrainerUserId))
            {
                dbContext.Users.Add(User(pair.TrainerUserId, UserRole.Trainer));
            }

            if (!await dbContext.Users.AnyAsync(user => user.Id == pair.TraineeUserId))
            {
                dbContext.Users.Add(User(pair.TraineeUserId, UserRole.Trainee, pair.TrainerUserId));
            }
        }

        dbContext.SharedSessions.AddRange(materialized);
        await dbContext.SaveChangesAsync();
    }

    private static ApplicationUser User(string id, string role, string? trainerUserId = null)
    {
        return new ApplicationUser
        {
            Id = id,
            UserName = $"{id}@example.test",
            NormalizedUserName = $"{id}@example.test".ToUpperInvariant(),
            Email = $"{id}@example.test",
            NormalizedEmail = $"{id}@example.test".ToUpperInvariant(),
            DisplayName = id,
            LiftMateRole = role,
            TrainerUserId = trainerUserId,
        };
    }

    private static SharedSession CompletedSession(
        string trainerUserId,
        string traineeUserId,
        Guid? exerciseId,
        string exerciseType,
        string exerciseName,
        decimal? weight,
        int closedAtOffsetDays,
        int? reps = 8,
        int? feedbackRating = null,
        string? feedbackComment = null)
    {
        var closedAt = DateTimeOffset.UtcNow.Date.AddDays(closedAtOffsetDays).AddHours(12);
        var session = new SharedSession
        {
            Id = Guid.NewGuid(),
            TrainerUserId = trainerUserId,
            TraineeUserId = traineeUserId,
            StartedByUserId = traineeUserId,
            StartedByRole = "trainee",
            WorkoutSetName = "Guidance test",
            Status = SharedSessionStatus.Completed,
            Version = 2,
            CreatedAt = closedAt.AddMinutes(-45),
            UpdatedAt = closedAt,
            ClosedAt = closedAt,
        };
        session.Values.Add(new SharedSessionValue
        {
            Id = Guid.NewGuid(),
            ExerciseId = exerciseId,
            WorkoutSetRowId = Guid.NewGuid(),
            ExerciseName = exerciseName,
            ExerciseType = exerciseType,
            ExerciseOrder = 1,
            SetIndex = 1,
            Reps = reps,
            Weight = weight,
            IsDone = true,
            CompletedAt = closedAt,
        });

        if (feedbackRating is not null)
        {
            session.Feedback = new PostWorkoutFeedback
            {
                SharedSessionId = session.Id,
                WellbeingRating = feedbackRating.Value,
                Comment = feedbackComment,
                SubmittedAt = closedAt.AddMinutes(1),
            };
        }

        return session;
    }
}
