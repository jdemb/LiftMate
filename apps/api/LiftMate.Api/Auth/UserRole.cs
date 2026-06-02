namespace LiftMate.Api.Auth;

public static class UserRole
{
    public const string Trainer = "trainer";
    public const string Trainee = "trainee";

    public static readonly string[] All = [Trainer, Trainee];
}
