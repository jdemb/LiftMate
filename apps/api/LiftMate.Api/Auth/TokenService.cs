using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using LiftMate.Api.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace LiftMate.Api.Auth;

public sealed class TokenService(IConfiguration configuration, ApplicationDbContext dbContext)
{
    public async Task<AuthResponse> CreateTokenPairAsync(ApplicationUser user, CancellationToken cancellationToken)
    {
        var accessTokenExpiresAt = DateTimeOffset.UtcNow.AddMinutes(GetInt("Jwt:AccessTokenMinutes", 15));
        var accessToken = CreateAccessToken(user, accessTokenExpiresAt);
        var refreshToken = GenerateToken();

        dbContext.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            TokenHash = HashToken(refreshToken),
            CreatedAt = DateTimeOffset.UtcNow,
            ExpiresAt = DateTimeOffset.UtcNow.AddDays(GetInt("Jwt:RefreshTokenDays", 30)),
        });
        await dbContext.SaveChangesAsync(cancellationToken);

        return new AuthResponse(accessToken, refreshToken, accessTokenExpiresAt, ToUserResponse(user));
    }

    public async Task<AuthResponse?> RefreshAsync(string refreshToken, CancellationToken cancellationToken)
    {
        var refreshTokenHash = HashToken(refreshToken);
        var storedToken = await dbContext.RefreshTokens
            .Include(token => token.User)
            .SingleOrDefaultAsync(token => token.TokenHash == refreshTokenHash, cancellationToken);

        if (storedToken?.User is null || storedToken.RevokedAt is not null || storedToken.ExpiresAt <= DateTimeOffset.UtcNow)
        {
            return null;
        }

        var replacement = GenerateToken();
        storedToken.RevokedAt = DateTimeOffset.UtcNow;
        storedToken.ReplacedByTokenHash = HashToken(replacement);

        var accessTokenExpiresAt = DateTimeOffset.UtcNow.AddMinutes(GetInt("Jwt:AccessTokenMinutes", 15));
        var accessToken = CreateAccessToken(storedToken.User, accessTokenExpiresAt);

        dbContext.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = storedToken.UserId,
            TokenHash = HashToken(replacement),
            CreatedAt = DateTimeOffset.UtcNow,
            ExpiresAt = DateTimeOffset.UtcNow.AddDays(GetInt("Jwt:RefreshTokenDays", 30)),
        });
        await dbContext.SaveChangesAsync(cancellationToken);

        return new AuthResponse(accessToken, replacement, accessTokenExpiresAt, ToUserResponse(storedToken.User));
    }

    public async Task<LogoutResult> LogoutAsync(string userId, string refreshToken, CancellationToken cancellationToken)
    {
        var refreshTokenHash = HashToken(refreshToken);
        var storedToken = await dbContext.RefreshTokens
            .SingleOrDefaultAsync(token => token.TokenHash == refreshTokenHash, cancellationToken);

        if (storedToken is null)
        {
            return LogoutResult.Forbidden;
        }

        if (!string.Equals(storedToken.UserId, userId, StringComparison.Ordinal))
        {
            return LogoutResult.Forbidden;
        }

        if (storedToken.RevokedAt is null)
        {
            storedToken.RevokedAt = DateTimeOffset.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return LogoutResult.Success;
    }

    public static UserResponse ToUserResponse(ApplicationUser user)
    {
        return new UserResponse(
            user.Id,
            user.Email ?? string.Empty,
            user.LiftMateRole,
            user.DisplayName,
            user.TrainerUserId);
    }

    private string CreateAccessToken(ApplicationUser user, DateTimeOffset expiresAt)
    {
        var signingKey = configuration["Jwt:SigningKey"];
        if (string.IsNullOrWhiteSpace(signingKey))
        {
            throw new InvalidOperationException("JWT signing key is not configured.");
        }

        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(signingKey)),
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: configuration["Jwt:Issuer"],
            audience: configuration["Jwt:Audience"],
            claims:
            [
                new Claim(JwtRegisteredClaimNames.Sub, user.Id),
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(ClaimTypes.Email, user.Email ?? string.Empty),
                new Claim(ClaimTypes.Role, user.LiftMateRole),
            ],
            expires: expiresAt.UtcDateTime,
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private int GetInt(string key, int fallback)
    {
        var configured = configuration[key];
        return int.TryParse(configured, NumberStyles.None, CultureInfo.InvariantCulture, out var value)
            ? value
            : fallback;
    }

    private static string GenerateToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(32);
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static string HashToken(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}

public enum LogoutResult
{
    Success,
    Forbidden,
}
