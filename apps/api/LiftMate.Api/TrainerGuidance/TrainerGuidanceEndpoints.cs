using System.Security.Claims;
using System.Text.Json;
using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.TrainerGuidance;

public static class TrainerGuidanceEndpoints
{
    public static RouteGroupBuilder MapTrainerGuidanceEndpoints(this IEndpointRouteBuilder routes)
    {
        var group = routes.MapGroup("/trainer-guidance")
            .RequireAuthorization("TrainerOnly");

        group.MapGet("/", List);
        group.MapPost("/{id:guid}/read", MarkAsRead);

        return group;
    }

    private static async Task<IResult> List(
        string traineeUserId,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        if (!await CanCurrentTrainerAccessTraineeAsync(principal, traineeUserId, dbContext, cancellationToken))
        {
            return Results.Forbid();
        }

        var guidance = await dbContext.TrainerGuidance
            .AsNoTracking()
            .Where(item =>
                item.TraineeUserId == traineeUserId &&
                item.ReadAt == null)
            .ToListAsync(cancellationToken);

        var response = guidance
            .OrderByDescending(item => item.CreatedAt)
            .ThenByDescending(item => item.Id)
            .Select(ToResponse)
            .ToArray();

        return Results.Ok(new TrainerGuidanceListResponse(response));
    }

    private static async Task<IResult> MarkAsRead(
        Guid id,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var guidance = await dbContext.TrainerGuidance
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (guidance is null)
        {
            return Results.NotFound();
        }

        if (!await CanCurrentTrainerAccessTraineeAsync(principal, guidance.TraineeUserId, dbContext, cancellationToken))
        {
            return Results.Forbid();
        }

        if (guidance.ReadAt is null)
        {
            guidance.ReadAt = DateTimeOffset.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return Results.Ok();
    }

    private static async Task<bool> CanCurrentTrainerAccessTraineeAsync(
        ClaimsPrincipal principal,
        string traineeUserId,
        ApplicationDbContext dbContext,
        CancellationToken cancellationToken)
    {
        var trainerUserId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (trainerUserId is null || !principal.HasClaim(ClaimTypes.Role, UserRole.Trainer))
        {
            return false;
        }

        return await dbContext.Users.AnyAsync(
            user =>
                user.Id == traineeUserId &&
                user.LiftMateRole == UserRole.Trainee &&
                user.TrainerUserId == trainerUserId,
            cancellationToken);
    }

    private static TrainerGuidanceResponse ToResponse(TrainerGuidance guidance)
    {
        using var document = JsonDocument.Parse(guidance.EvidenceJson);
        return new TrainerGuidanceResponse(
            guidance.Id,
            guidance.Type,
            guidance.TraineeUserId,
            guidance.ExerciseId,
            guidance.ExerciseName,
            guidance.Message,
            document.RootElement.Clone(),
            guidance.CreatedAt);
    }
}
