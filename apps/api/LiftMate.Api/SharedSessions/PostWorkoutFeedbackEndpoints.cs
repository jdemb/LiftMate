using System.Security.Claims;
using LiftMate.Api.Auth;
using LiftMate.Api.Data;
using LiftMate.Api.TrainerGuidance;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.SharedSessions;

public static class PostWorkoutFeedbackEndpoints
{
    private const int MaxCommentLength = 1000;

    public static RouteGroupBuilder MapPostWorkoutFeedbackEndpoints(this IEndpointRouteBuilder routes)
    {
        var group = routes.MapGroup("/shared-sessions");
        group.MapPost("/{sessionId:guid}/feedback", Create).RequireAuthorization("TraineeOnly");
        return group;
    }

    private static async Task<IResult> Create(
        Guid sessionId,
        CreatePostWorkoutFeedbackRequest request,
        ClaimsPrincipal principal,
        ApplicationDbContext dbContext,
        TrainerGuidanceEvaluator guidanceEvaluator,
        CancellationToken cancellationToken)
    {
        var validationError = NormalizeAndValidate(request, out var normalizedComment);
        if (validationError is not null)
        {
            return Results.BadRequest(new { error = validationError });
        }

        var userId = SharedSessionAccess.UserId(principal);
        if (userId is null)
        {
            return Results.Unauthorized();
        }

        var session = await dbContext.SharedSessions
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == sessionId, cancellationToken);
        if (session is null || !string.Equals(session.TraineeUserId, userId, StringComparison.Ordinal))
        {
            return Results.NotFound();
        }

        if (session.Status != SharedSessionStatus.Completed || session.ClosedAt is null)
        {
            return Results.Conflict(new { error = "Shared session must be completed before feedback can be submitted." });
        }

        var existing = await dbContext.PostWorkoutFeedbacks
            .AsNoTracking()
            .SingleOrDefaultAsync(feedback => feedback.SharedSessionId == sessionId, cancellationToken);
        if (existing is not null)
        {
            return ReplayResult(existing, request.WellbeingRating, normalizedComment);
        }

        var feedback = new PostWorkoutFeedback
        {
            SharedSessionId = sessionId,
            WellbeingRating = request.WellbeingRating,
            Comment = normalizedComment,
            SubmittedAt = DateTimeOffset.UtcNow,
        };

        dbContext.PostWorkoutFeedbacks.Add(feedback);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex)
        {
            foreach (var entry in ex.Entries)
            {
                entry.State = EntityState.Detached;
            }

            dbContext.ChangeTracker.Clear();
            existing = await dbContext.PostWorkoutFeedbacks
                .AsNoTracking()
                .SingleOrDefaultAsync(item => item.SharedSessionId == sessionId, cancellationToken);
            if (existing is null)
            {
                throw;
            }

            return ReplayResult(existing, request.WellbeingRating, normalizedComment);
        }

        await guidanceEvaluator.EvaluateLowWellbeingAsync(session.TraineeUserId, cancellationToken);
        return Results.Created($"/shared-sessions/{sessionId}/feedback", ToResponse(feedback));
    }

    private static string? NormalizeAndValidate(
        CreatePostWorkoutFeedbackRequest request,
        out string? normalizedComment)
    {
        normalizedComment = string.IsNullOrWhiteSpace(request.Comment)
            ? null
            : request.Comment.Trim();

        if (request.WellbeingRating is < 1 or > 5)
        {
            return "Wellbeing rating must be between 1 and 5.";
        }

        if (normalizedComment is { Length: > MaxCommentLength })
        {
            return $"Comment must be at most {MaxCommentLength} characters.";
        }

        return null;
    }

    private static IResult ReplayResult(
        PostWorkoutFeedback existing,
        int wellbeingRating,
        string? normalizedComment)
    {
        if (existing.WellbeingRating == wellbeingRating &&
            string.Equals(existing.Comment, normalizedComment, StringComparison.Ordinal))
        {
            return Results.Ok(ToResponse(existing));
        }

        return Results.Conflict(new { error = "Feedback has already been submitted for this session." });
    }

    private static PostWorkoutFeedbackResponse ToResponse(PostWorkoutFeedback feedback)
    {
        return new PostWorkoutFeedbackResponse(
            feedback.SharedSessionId,
            feedback.WellbeingRating,
            feedback.Comment,
            feedback.SubmittedAt);
    }
}
