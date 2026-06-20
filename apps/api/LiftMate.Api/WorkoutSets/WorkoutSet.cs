using LiftMate.Api.Auth;

namespace LiftMate.Api.WorkoutSets;

public sealed class WorkoutSet
{
    public Guid Id { get; set; }

    public string TrainerUserId { get; set; } = string.Empty;

    public ApplicationUser? TrainerUser { get; set; }

    public string Name { get; set; } = string.Empty;

    public int RestSeconds { get; set; } = 90;

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public ICollection<WorkoutSetRow> Rows { get; } = new List<WorkoutSetRow>();

    public ICollection<WorkoutSetAssignment> Assignments { get; } = new List<WorkoutSetAssignment>();
}
