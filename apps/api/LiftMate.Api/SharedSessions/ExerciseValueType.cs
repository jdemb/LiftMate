namespace LiftMate.Api.SharedSessions;

public static class ExerciseValueType
{
    public const string RepsWeight = "repsWeight";
    public const string RepsOnly = "repsOnly";
    public const string Time = "time";

    public static readonly string[] All = [RepsWeight, RepsOnly, Time];

    public static bool IsValid(string value)
    {
        return All.Contains(value, StringComparer.Ordinal);
    }
}
