namespace LiftMate.Api.SharedSessions;

public static class SharedSessionStatus
{
    public const string Active = "active";
    public const string Completed = "completed";
    public const string Cancelled = "cancelled";

    public static readonly string[] All = [Active, Completed, Cancelled];

    public static bool IsValid(string value)
    {
        return All.Contains(value, StringComparer.Ordinal);
    }
}
