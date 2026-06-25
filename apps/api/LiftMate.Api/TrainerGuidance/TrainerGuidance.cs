namespace LiftMate.Api.TrainerGuidance;

public sealed class TrainerGuidance
{
    public Guid Id { get; set; }

    public string TraineeUserId { get; set; } = string.Empty;

    public string Type { get; set; } = string.Empty;

    public Guid? ExerciseId { get; set; }

    public string? ExerciseName { get; set; }

    public string Fingerprint { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    public string EvidenceJson { get; set; } = "{}";

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? ReadAt { get; set; }
}
