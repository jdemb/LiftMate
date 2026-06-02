using LiftMate.Api.Auth;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace LiftMate.Api.Data;

public sealed class ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
    : IdentityUserContext<ApplicationUser>(options)
{
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

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
    }
}
