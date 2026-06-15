using System.Security.Claims;
using System.Security.Cryptography;
using LiftMate.Api.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.Auth;

public static class PairingEndpoints
{
    private const string InviteCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private const int InviteCodeLength = 6;
    private const int MaxCodeGenerationAttempts = 8;

    public static IEndpointRouteBuilder MapPairingEndpoints(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/trainer/invite-code", GenerateTrainerInviteCode)
            .RequireAuthorization("TrainerOnly");

        routes.MapPost("/trainee/trainer-link", ClaimTrainerInviteCode)
            .RequireAuthorization("TraineeOnly");

        return routes;
    }

    private static async Task<IResult> GenerateTrainerInviteCode(
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var trainerUserId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (trainerUserId is null)
        {
            return Results.Unauthorized();
        }

        var existing = await dbContext.TrainerInviteCodes.SingleOrDefaultAsync(
            inviteCode => inviteCode.TrainerUserId == trainerUserId,
            cancellationToken);
        if (existing is not null)
        {
            return Results.Ok(new TrainerInviteCodeResponse(existing.Code));
        }

        for (var attempt = 0; attempt < MaxCodeGenerationAttempts; attempt += 1)
        {
            var code = GenerateCode();
            var isTaken = await dbContext.TrainerInviteCodes.AnyAsync(
                inviteCode => inviteCode.Code == code,
                cancellationToken);
            if (isTaken)
            {
                continue;
            }

            var inviteCode = new TrainerInviteCode
            {
                Id = Guid.NewGuid(),
                Code = code,
                TrainerUserId = trainerUserId,
                CreatedAt = DateTimeOffset.UtcNow,
            };

            dbContext.TrainerInviteCodes.Add(inviteCode);
            await dbContext.SaveChangesAsync(cancellationToken);

            return Results.Ok(new TrainerInviteCodeResponse(inviteCode.Code));
        }

        return Results.Problem("Could not generate a unique invite code.");
    }

    private static async Task<IResult> ClaimTrainerInviteCode(
        ClaimTrainerInviteCodeRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        UserManager<ApplicationUser> userManager,
        CancellationToken cancellationToken)
    {
        var traineeUserId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (traineeUserId is null)
        {
            return Results.Unauthorized();
        }

        var code = NormalizeCode(request.Code);
        if (code is null)
        {
            return Results.BadRequest(new { error = "Invite code is required." });
        }

        var trainee = await userManager.Users.SingleOrDefaultAsync(
            user => user.Id == traineeUserId,
            cancellationToken);
        if (trainee is null)
        {
            return Results.Unauthorized();
        }

        if (trainee.LiftMateRole != UserRole.Trainee)
        {
            return Results.Forbid();
        }

        if (trainee.TrainerUserId is not null)
        {
            return Results.Conflict(new { error = "Trainee is already linked to a trainer." });
        }

        var inviteCode = await dbContext.TrainerInviteCodes
            .Include(value => value.TrainerUser)
            .SingleOrDefaultAsync(value => value.Code == code, cancellationToken);
        if (inviteCode?.TrainerUser is null)
        {
            return Results.NotFound(new { error = "Trainer invite code was not found." });
        }

        if (inviteCode.TrainerUser.LiftMateRole != UserRole.Trainer)
        {
            return Results.BadRequest(new { error = "Invite code owner is not a trainer." });
        }

        if (inviteCode.TrainerUserId == trainee.Id)
        {
            return Results.BadRequest(new { error = "A trainee cannot link to themselves." });
        }

        trainee.TrainerUserId = inviteCode.TrainerUserId;
        inviteCode.LastUsedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        return Results.Ok(TokenService.ToUserResponse(trainee));
    }

    private static string GenerateCode()
    {
        Span<char> code = stackalloc char[InviteCodeLength];
        Span<byte> random = stackalloc byte[InviteCodeLength];
        RandomNumberGenerator.Fill(random);

        for (var i = 0; i < code.Length; i += 1)
        {
            code[i] = InviteCodeAlphabet[random[i] % InviteCodeAlphabet.Length];
        }

        return new string(code);
    }

    private static string? NormalizeCode(string code)
    {
        var normalized = code.Trim().ToUpperInvariant();
        if (normalized.Length != InviteCodeLength)
        {
            return null;
        }

        return normalized.All(InviteCodeAlphabet.Contains) ? normalized : null;
    }
}
