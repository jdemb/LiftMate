using LiftMate.Api.Auth;
using LiftMate.Api.SharedSessions;
using LiftMate.Api.TrainingProgress;
using LiftMate.Api.WorkoutSets;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.Data;

public sealed class ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
    : IdentityUserContext<ApplicationUser>(options)
{
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    public DbSet<TrainerInviteCode> TrainerInviteCodes => Set<TrainerInviteCode>();

    public DbSet<SharedSession> SharedSessions => Set<SharedSession>();

    public DbSet<SharedSessionValue> SharedSessionValues => Set<SharedSessionValue>();

    public DbSet<PostWorkoutFeedback> PostWorkoutFeedbacks => Set<PostWorkoutFeedback>();

    public DbSet<WorkoutSet> WorkoutSets => Set<WorkoutSet>();

    public DbSet<WorkoutSetRow> WorkoutSetRows => Set<WorkoutSetRow>();

    public DbSet<WorkoutSetAssignment> WorkoutSetAssignments => Set<WorkoutSetAssignment>();

    public DbSet<WorkoutProgress> WorkoutProgresses => Set<WorkoutProgress>();

    public DbSet<WorkoutProgressValue> WorkoutProgressValues => Set<WorkoutProgressValue>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<ApplicationUser>(entity =>
        {
            entity.Property(user => user.DisplayName)
                .HasMaxLength(200)
                .IsRequired();

            entity.Property(user => user.LiftMateRole)
                .HasMaxLength(32)
                .IsRequired();

            entity.Property(user => user.TrainerUserId)
                .HasMaxLength(450);

            entity.HasIndex(user => user.TrainerUserId);

            entity.HasOne(user => user.TrainerUser)
                .WithMany(user => user.Trainees)
                .HasForeignKey(user => user.TrainerUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.ToTable(table => table.HasCheckConstraint(
                "CK_AspNetUsers_LiftMateRole",
                "[LiftMateRole] IN ('trainer', 'trainee')"));
        });

        builder.Entity<TrainerInviteCode>(entity =>
        {
            entity.HasKey(inviteCode => inviteCode.Id);

            entity.Property(inviteCode => inviteCode.Code)
                .HasMaxLength(6)
                .IsRequired();

            entity.Property(inviteCode => inviteCode.TrainerUserId)
                .HasMaxLength(450)
                .IsRequired();

            entity.HasIndex(inviteCode => inviteCode.Code)
                .IsUnique();

            entity.HasIndex(inviteCode => inviteCode.TrainerUserId)
                .IsUnique();

            entity.HasOne(inviteCode => inviteCode.TrainerUser)
                .WithMany()
                .HasForeignKey(inviteCode => inviteCode.TrainerUserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<RefreshToken>(entity =>
        {
            entity.HasKey(refreshToken => refreshToken.Id);

            entity.Property(refreshToken => refreshToken.TokenHash)
                .HasMaxLength(128)
                .IsRequired();

            entity.Property(refreshToken => refreshToken.UserId)
                .HasMaxLength(450)
                .IsRequired();

            entity.Property(refreshToken => refreshToken.ReplacedByTokenHash)
                .HasMaxLength(128);

            entity.HasIndex(refreshToken => refreshToken.TokenHash)
                .IsUnique();

            entity.HasOne(refreshToken => refreshToken.User)
                .WithMany(user => user.RefreshTokens)
                .HasForeignKey(refreshToken => refreshToken.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<SharedSession>(entity =>
        {
            entity.HasKey(session => session.Id);

            entity.Property(session => session.TrainerUserId)
                .HasMaxLength(450)
                .IsRequired();

            entity.Property(session => session.TraineeUserId)
                .HasMaxLength(450)
                .IsRequired();

            entity.Property(session => session.StartedByUserId)
                .HasMaxLength(450)
                .IsRequired();

            entity.Property(session => session.StartedByRole)
                .HasMaxLength(32)
                .IsRequired();

            entity.Property(session => session.Status)
                .HasMaxLength(32)
                .IsRequired();

            entity.Property(session => session.WorkoutSetName)
                .HasMaxLength(200)
                .IsRequired();

            entity.Property(session => session.RestSeconds)
                .HasDefaultValue(90)
                .IsRequired();

            entity.HasIndex(session => session.WorkoutSetId);
            entity.HasIndex(session => session.StartedByUserId);
            entity.HasIndex(session => session.TrainerUserId);
            entity.HasIndex(session => session.TraineeUserId);
            entity.HasIndex(session => session.TraineeUserId)
                .IsUnique()
                .HasFilter("[Status] = 'active'");
            entity.HasIndex(session => session.Status);

            entity.HasOne(session => session.TrainerUser)
                .WithMany()
                .HasForeignKey(session => session.TrainerUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(session => session.TraineeUser)
                .WithMany()
                .HasForeignKey(session => session.TraineeUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(session => session.WorkoutSet)
                .WithMany()
                .HasForeignKey(session => session.WorkoutSetId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(session => session.StartedByUser)
                .WithMany()
                .HasForeignKey(session => session.StartedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasMany(session => session.Values)
                .WithOne(value => value.SharedSession)
                .HasForeignKey(value => value.SharedSessionId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(session => session.Feedback)
                .WithOne(feedback => feedback.SharedSession)
                .HasForeignKey<PostWorkoutFeedback>(feedback => feedback.SharedSessionId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.ToTable(table =>
            {
                table.HasCheckConstraint(
                    "CK_SharedSessions_Status",
                    "[Status] IN ('active', 'completed', 'cancelled')");
                table.HasCheckConstraint(
                    "CK_SharedSessions_StartedByRole",
                    "[StartedByRole] IN ('trainer', 'trainee')");
                table.HasCheckConstraint(
                    "CK_SharedSessions_RestSeconds",
                    "[RestSeconds] BETWEEN 15 AND 600");
            });
        });

        builder.Entity<PostWorkoutFeedback>(entity =>
        {
            entity.HasKey(feedback => feedback.SharedSessionId);

            entity.Property(feedback => feedback.Comment)
                .HasMaxLength(1000);

            entity.Property(feedback => feedback.SubmittedAt)
                .IsRequired();

            entity.ToTable(table => table.HasCheckConstraint(
                "CK_PostWorkoutFeedbacks_WellbeingRating",
                "[WellbeingRating] BETWEEN 1 AND 5"));
        });

        builder.Entity<SharedSessionValue>(entity =>
        {
            entity.HasKey(value => value.Id);

            entity.Property(value => value.ExerciseName)
                .HasMaxLength(200)
                .IsRequired();

            entity.Property(value => value.ExerciseType)
                .HasMaxLength(32)
                .IsRequired();

            entity.Property(value => value.Weight)
                .HasPrecision(8, 2);

            entity.Property(value => value.IsDone)
                .IsRequired();

            entity.Property(value => value.UpdatedByUserId)
                .HasMaxLength(450);

            entity.HasIndex(value => value.SharedSessionId);
            entity.HasIndex(value => new { value.SharedSessionId, value.ExerciseOrder, value.SetIndex });
            entity.HasIndex(value => value.ExerciseId);
            entity.HasIndex(value => value.WorkoutSetRowId);
            entity.HasIndex(value => value.ExerciseType);

            entity.HasOne(value => value.UpdatedByUser)
                .WithMany()
                .HasForeignKey(value => value.UpdatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.ToTable(table => table.HasCheckConstraint(
                "CK_SharedSessionValues_ExerciseType",
                "[ExerciseType] IN ('repsWeight', 'repsOnly', 'time')"));
        });

        builder.Entity<WorkoutSet>(entity =>
        {
            entity.HasKey(workoutSet => workoutSet.Id);

            entity.Property(workoutSet => workoutSet.TrainerUserId)
                .HasMaxLength(450)
                .IsRequired();

            entity.Property(workoutSet => workoutSet.Name)
                .HasMaxLength(200)
                .IsRequired();

            entity.Property(workoutSet => workoutSet.RestSeconds)
                .HasDefaultValue(90)
                .IsRequired();

            entity.HasIndex(workoutSet => workoutSet.TrainerUserId);

            entity.HasOne(workoutSet => workoutSet.TrainerUser)
                .WithMany()
                .HasForeignKey(workoutSet => workoutSet.TrainerUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasMany(workoutSet => workoutSet.Rows)
                .WithOne(row => row.WorkoutSet)
                .HasForeignKey(row => row.WorkoutSetId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasMany(workoutSet => workoutSet.Assignments)
                .WithOne(assignment => assignment.WorkoutSet)
                .HasForeignKey(assignment => assignment.WorkoutSetId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.ToTable(table => table.HasCheckConstraint(
                "CK_WorkoutSets_RestSeconds",
                "[RestSeconds] BETWEEN 15 AND 600"));
        });

        builder.Entity<WorkoutSetRow>(entity =>
        {
            entity.HasKey(row => row.Id);

            entity.Property(row => row.ExerciseName)
                .HasMaxLength(200)
                .IsRequired();

            entity.Property(row => row.ExerciseType)
                .HasMaxLength(32)
                .IsRequired();

            entity.Property(row => row.Weight)
                .HasPrecision(8, 2);

            entity.HasIndex(row => row.WorkoutSetId);
            entity.HasIndex(row => new { row.WorkoutSetId, row.ExerciseOrder, row.SetIndex });
            entity.HasIndex(row => new { row.WorkoutSetId, row.ExerciseId, row.SetIndex });
            entity.HasIndex(row => row.ExerciseType);

            entity.ToTable(table => table.HasCheckConstraint(
                "CK_WorkoutSetRows_ExerciseType",
                "[ExerciseType] IN ('repsWeight', 'repsOnly', 'time')"));
        });

        builder.Entity<WorkoutSetAssignment>(entity =>
        {
            entity.HasKey(assignment => assignment.Id);

            entity.Property(assignment => assignment.TraineeUserId)
                .HasMaxLength(450)
                .IsRequired();

            entity.Property(assignment => assignment.AssignedByTrainerUserId)
                .HasMaxLength(450)
                .IsRequired();

            entity.HasIndex(assignment => assignment.WorkoutSetId);
            entity.HasIndex(assignment => assignment.TraineeUserId);
            entity.HasIndex(assignment => new { assignment.WorkoutSetId, assignment.TraineeUserId })
                .IsUnique();

            entity.HasOne(assignment => assignment.TraineeUser)
                .WithMany()
                .HasForeignKey(assignment => assignment.TraineeUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<WorkoutProgress>(entity =>
        {
            entity.HasKey(progress => progress.Id);

            entity.Property(progress => progress.TraineeUserId)
                .HasMaxLength(450)
                .IsRequired();

            entity.HasIndex(progress => new { progress.TraineeUserId, progress.WorkoutSetId })
                .IsUnique();
            entity.HasIndex(progress => progress.SourceSessionId)
                .IsUnique();

            entity.HasOne(progress => progress.WorkoutSet)
                .WithMany()
                .HasForeignKey(progress => progress.WorkoutSetId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasMany(progress => progress.Values)
                .WithOne(value => value.WorkoutProgress)
                .HasForeignKey(value => value.WorkoutProgressId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<WorkoutProgressValue>(entity =>
        {
            entity.HasKey(value => value.Id);

            entity.Property(value => value.ExerciseType)
                .HasMaxLength(32)
                .IsRequired();

            entity.Property(value => value.Weight)
                .HasPrecision(8, 2);

            entity.HasIndex(value => new { value.WorkoutProgressId, value.WorkoutSetRowId })
                .IsUnique();
            entity.HasIndex(value => value.ExerciseId);

            entity.ToTable(table => table.HasCheckConstraint(
                "CK_WorkoutProgressValues_ExerciseType",
                "[ExerciseType] IN ('repsWeight', 'repsOnly', 'time')"));
        });
    }
}
