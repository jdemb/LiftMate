using LiftMate.Api.Auth;

namespace LiftMate.Api.WorkoutSets;

public sealed class WorkoutSetAssignment
{
    public Guid Id { get; set; }

    public Guid WorkoutSetId { get; set; }

    public WorkoutSet? WorkoutSet { get; set; }

    public string TraineeUserId { get; set; } = string.Empty;

    public ApplicationUser? TraineeUser { get; set; }

    public string AssignedByTrainerUserId { get; set; } = string.Empty;

    public DateTimeOffset AssignedAt { get; set; }
}
