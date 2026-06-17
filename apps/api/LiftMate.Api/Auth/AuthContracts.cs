namespace LiftMate.Api.Auth;

public sealed record RegisterRequest(
    string Email,
    string Password,
    string Role,
    string DisplayName);

public sealed record LoginRequest(string Email, string Password);

public sealed record RefreshRequest(string RefreshToken);

public sealed record LogoutRequest(string RefreshToken);

public sealed record AuthResponse(
    string AccessToken,
    string RefreshToken,
    DateTimeOffset ExpiresAt,
    UserResponse User);

public sealed record UserResponse(
    string Id,
    string Email,
    string Role,
    string DisplayName,
    string? TrainerUserId);

public sealed record ProbeResponse(string Role);

public sealed record TrainerInviteCodeResponse(string Code);

public sealed record ClaimTrainerInviteCodeRequest(string Code);

public sealed record TrainerTraineeResponse(
    string Id,
    string Email,
    string DisplayName,
    ActiveSharedSessionSummaryResponse? ActiveSession);

public sealed record ActiveSharedSessionSummaryResponse(
    Guid SessionId,
    Guid? WorkoutSetId,
    string? WorkoutSetName,
    string StartedByUserId,
    string StartedByRole,
    DateTimeOffset UpdatedAt);

public sealed record TrainerRelationshipSummaryResponse(
    string InviteCode,
    IReadOnlyList<TrainerTraineeResponse> Trainees);

public sealed record TraineeTrainerResponse(
    string Id,
    string Email,
    string DisplayName);

public sealed record TraineeRelationshipSummaryResponse(TraineeTrainerResponse? Trainer);
