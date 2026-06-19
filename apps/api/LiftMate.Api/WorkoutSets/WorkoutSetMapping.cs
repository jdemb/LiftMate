namespace LiftMate.Api.WorkoutSets;

public static class WorkoutSetMapping
{
    public static WorkoutSetSummaryResponse ToSummary(WorkoutSet workoutSet)
    {
        var currentAssignments = CurrentAssignments(workoutSet).ToArray();

        return new WorkoutSetSummaryResponse(
            workoutSet.Id,
            workoutSet.Name,
            workoutSet.Rows.Select(row => row.ExerciseOrder).Distinct().Count(),
            workoutSet.Rows.Count,
            currentAssignments.Length,
            workoutSet.CreatedAt,
            workoutSet.UpdatedAt);
    }

    public static WorkoutSetDetailResponse ToDetail(WorkoutSet workoutSet)
    {
        return new WorkoutSetDetailResponse(
            workoutSet.Id,
            workoutSet.Name,
            OrderedRows(workoutSet).Select(ToRowResponse).ToArray(),
            CurrentAssignments(workoutSet)
                .OrderBy(assignment => assignment.TraineeUser?.DisplayName)
                .ThenBy(assignment => assignment.TraineeUser?.Email)
                .Select(ToAssignmentResponse)
                .ToArray(),
            workoutSet.CreatedAt,
            workoutSet.UpdatedAt);
    }

    public static TraineeAssignedWorkoutSetResponse ToTraineeAssigned(
        WorkoutSetAssignment assignment)
    {
        var workoutSet = assignment.WorkoutSet ?? throw new InvalidOperationException("Workout set must be loaded.");

        return new TraineeAssignedWorkoutSetResponse(
            workoutSet.Id,
            workoutSet.Name,
            workoutSet.TrainerUser?.DisplayName ?? string.Empty,
            OrderedRows(workoutSet).Select(ToRowResponse).ToArray(),
            assignment.AssignedAt,
            workoutSet.UpdatedAt);
    }

    private static IEnumerable<WorkoutSetRow> OrderedRows(WorkoutSet workoutSet)
    {
        return workoutSet.Rows
            .OrderBy(row => row.ExerciseOrder)
            .ThenBy(row => row.SetIndex)
            .ThenBy(row => row.Id);
    }

    private static IEnumerable<WorkoutSetAssignment> CurrentAssignments(WorkoutSet workoutSet)
    {
        return workoutSet.Assignments
            .Where(assignment => assignment.TraineeUser?.TrainerUserId == workoutSet.TrainerUserId);
    }

    private static WorkoutSetRowResponse ToRowResponse(WorkoutSetRow row)
    {
        return new WorkoutSetRowResponse(
            row.Id,
            row.ExerciseId,
            row.ExerciseOrder,
            row.SetIndex,
            row.ExerciseName,
            row.ExerciseType,
            row.Reps,
            row.Weight,
            row.Seconds);
    }

    private static WorkoutSetAssignmentResponse ToAssignmentResponse(WorkoutSetAssignment assignment)
    {
        return new WorkoutSetAssignmentResponse(
            assignment.TraineeUserId,
            assignment.TraineeUser?.Email ?? string.Empty,
            assignment.TraineeUser?.DisplayName ?? assignment.TraineeUser?.Email ?? string.Empty,
            assignment.AssignedAt);
    }
}
