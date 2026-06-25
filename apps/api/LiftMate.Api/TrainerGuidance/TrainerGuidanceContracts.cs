using System.Text.Json;

namespace LiftMate.Api.TrainerGuidance;

public sealed record TrainerGuidanceListResponse(
    IReadOnlyList<TrainerGuidanceResponse> Items);

public sealed record TrainerGuidanceResponse(
    Guid Id,
    string Type,
    string TraineeUserId,
    Guid? ExerciseId,
    string? ExerciseName,
    string Message,
    JsonElement Evidence,
    DateTimeOffset CreatedAt);
