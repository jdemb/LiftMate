using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class OneActiveSharedSessionPerTrainee : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_SharedSessions_TraineeUserId",
                table: "SharedSessions");

            migrationBuilder.Sql(
                """
                WITH RankedActiveSessions AS (
                    SELECT
                        [Id],
                        ROW_NUMBER() OVER (
                            PARTITION BY [TraineeUserId]
                            ORDER BY [UpdatedAt] DESC, [CreatedAt] DESC, [Id] DESC
                        ) AS [Rank]
                    FROM [SharedSessions]
                    WHERE [Status] = 'active'
                )
                UPDATE [SharedSessions]
                SET
                    [Status] = 'cancelled',
                    [ClosedAt] = SYSUTCDATETIME(),
                    [UpdatedAt] = SYSUTCDATETIME(),
                    [Version] = [Version] + 1
                WHERE [Id] IN (
                    SELECT [Id]
                    FROM [RankedActiveSessions]
                    WHERE [Rank] > 1
                );
                """);

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessions_TraineeUserId",
                table: "SharedSessions",
                column: "TraineeUserId",
                unique: true,
                filter: "[Status] = 'active'");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_SharedSessions_TraineeUserId",
                table: "SharedSessions");

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessions_TraineeUserId",
                table: "SharedSessions",
                column: "TraineeUserId");
        }
    }
}
