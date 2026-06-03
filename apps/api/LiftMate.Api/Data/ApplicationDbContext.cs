using LiftMate.Api.Auth;
using LiftMate.Api.SharedSessions;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.Data;

public sealed class ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
    : IdentityUserContext<ApplicationUser>(options)
{
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    public DbSet<SharedSession> SharedSessions => Set<SharedSession>();

    public DbSet<SharedSessionValue> SharedSessionValues => Set<SharedSessionValue>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<ApplicationUser>(entity =>
        {
            entity.Property(user => user.LiftMateRole)
                .HasMaxLength(32)
                .IsRequired();

            entity.ToTable(table => table.HasCheckConstraint(
                "CK_AspNetUsers_LiftMateRole",
                "[LiftMateRole] IN ('trainer', 'trainee')"));
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

            entity.Property(session => session.Status)
                .HasMaxLength(32)
                .IsRequired();

            entity.HasIndex(session => session.TrainerUserId);
            entity.HasIndex(session => session.TraineeUserId);
            entity.HasIndex(session => session.Status);

            entity.HasOne(session => session.TrainerUser)
                .WithMany()
                .HasForeignKey(session => session.TrainerUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(session => session.TraineeUser)
                .WithMany()
                .HasForeignKey(session => session.TraineeUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasMany(session => session.Values)
                .WithOne(value => value.SharedSession)
                .HasForeignKey(value => value.SharedSessionId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.ToTable(table => table.HasCheckConstraint(
                "CK_SharedSessions_Status",
                "[Status] IN ('active', 'completed', 'cancelled')"));
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

            entity.Property(value => value.UpdatedByUserId)
                .HasMaxLength(450);

            entity.HasIndex(value => value.SharedSessionId);
            entity.HasIndex(value => value.ExerciseType);

            entity.HasOne(value => value.UpdatedByUser)
                .WithMany()
                .HasForeignKey(value => value.UpdatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.ToTable(table => table.HasCheckConstraint(
                "CK_SharedSessionValues_ExerciseType",
                "[ExerciseType] IN ('repsWeight', 'repsOnly', 'time')"));
        });
    }
}
