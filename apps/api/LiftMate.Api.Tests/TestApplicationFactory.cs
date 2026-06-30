using System.Data.Common;
using LiftMate.Api.Tests.Auth;
using LiftMate.Api.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace LiftMate.Api.Tests;

public sealed class TestApplicationFactory : WebApplicationFactory<Program>
{
    private readonly string _connectionString;
    private readonly DbConnection _connection;
    private readonly string? _registrationInviteCode;

    public TestApplicationFactory()
        : this(AuthEndpointTests.TestRegistrationInviteCode)
    {
    }

    internal TestApplicationFactory(string? registrationInviteCode)
    {
        _registrationInviteCode = registrationInviteCode;
        _connectionString = $"Data Source=LiftMateTests-{Guid.NewGuid():N};Mode=Memory;Cache=Shared;Default Timeout=30";
        _connection = CreateConnection(_connectionString);
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration(configuration =>
        {
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:Issuer"] = "LiftMate.Api.Tests",
                ["Jwt:Audience"] = "LiftMate.Api.Tests",
                ["Jwt:SigningKey"] = "test-signing-key-with-enough-entropy-for-hmac",
                ["Jwt:AccessTokenMinutes"] = "15",
                ["Jwt:RefreshTokenDays"] = "30",
                ["Auth:RegistrationInviteCode"] = _registrationInviteCode,
            });
        });

        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<ApplicationDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<ApplicationDbContext>>();
            services.RemoveAll<DbConnection>();

            services.AddDbContext<ApplicationDbContext>(options =>
            {
                options.UseSqlite(_connectionString);
            });

            using var scope = services.BuildServiceProvider().CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            dbContext.Database.EnsureCreated();
        });
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        if (disposing)
        {
            _connection.Dispose();
        }
    }

    private static DbConnection CreateConnection(string connectionString)
    {
        var connection = new SqliteConnection(connectionString);
        connection.Open();
        return connection;
    }
}
