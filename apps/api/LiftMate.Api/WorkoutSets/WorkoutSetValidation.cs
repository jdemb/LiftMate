using LiftMate.Api.SharedSessions;

namespace LiftMate.Api.WorkoutSets;

public static class WorkoutSetValidation
{
    public static string? ValidateSetName(string name)
    {
        return string.IsNullOrWhiteSpace(name)
            ? "Workout set name is required."
            : null;
    }

    public static string? ValidateRow(
        int exerciseOrder,
        int setIndex,
        string exerciseName,
        string exerciseType,
        int? reps,
        decimal? weight,
        int? seconds)
    {
        if (exerciseOrder < 1)
        {
            return "Exercise order must be greater than zero.";
        }

        if (setIndex < 1)
        {
            return "Set index must be greater than zero.";
        }

        if (string.IsNullOrWhiteSpace(exerciseName))
        {
            return "Exercise name is required.";
        }

        var type = exerciseType.Trim();
        return type switch
        {
            ExerciseValueType.RepsWeight when reps is null || weight is null => "Reps and weight are required for repsWeight values.",
            ExerciseValueType.RepsWeight when seconds is not null => "Seconds are not allowed for repsWeight values.",
            ExerciseValueType.RepsOnly when reps is null => "Reps are required for repsOnly values.",
            ExerciseValueType.RepsOnly when weight is not null || seconds is not null => "Weight and seconds are not allowed for repsOnly values.",
            ExerciseValueType.Time when seconds is null => "Seconds are required for time values.",
            ExerciseValueType.Time when reps is not null || weight is not null => "Reps and weight are not allowed for time values.",
            _ when !ExerciseValueType.IsValid(type) => "Invalid exercise type.",
            _ => null,
        };
    }
}
