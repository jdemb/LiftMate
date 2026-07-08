using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSharedSessionRestTimer : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "RestTimerEndsAt",
                table: "SharedSessions",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RestTimerRemainingSeconds",
                table: "SharedSessions",
                type: "int",
                nullable: false,
                defaultValue: 90);

            migrationBuilder.AddColumn<int>(
                name: "RestTimerTotalSeconds",
                table: "SharedSessions",
                type: "int",
                nullable: false,
                defaultValue: 90);

            migrationBuilder.Sql(
                """
                UPDATE [SharedSessions]
                SET [RestTimerTotalSeconds] = CASE
                        WHEN [RestSeconds] < 0 THEN 0
                        WHEN [RestSeconds] > 3600 THEN 3600
                        ELSE [RestSeconds]
                    END,
                    [RestTimerRemainingSeconds] = CASE
                        WHEN [RestSeconds] < 0 THEN 0
                        WHEN [RestSeconds] > 3600 THEN 3600
                        ELSE [RestSeconds]
                    END;
                """);

            migrationBuilder.AddCheckConstraint(
                name: "CK_SharedSessions_RestTimerRemainingSeconds",
                table: "SharedSessions",
                sql: "[RestTimerRemainingSeconds] BETWEEN 0 AND 3600");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SharedSessions_RestTimerTotalSeconds",
                table: "SharedSessions",
                sql: "[RestTimerTotalSeconds] BETWEEN 0 AND 3600");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_SharedSessions_RestTimerRemainingSeconds",
                table: "SharedSessions");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SharedSessions_RestTimerTotalSeconds",
                table: "SharedSessions");

            migrationBuilder.DropColumn(
                name: "RestTimerEndsAt",
                table: "SharedSessions");

            migrationBuilder.DropColumn(
                name: "RestTimerRemainingSeconds",
                table: "SharedSessions");

            migrationBuilder.DropColumn(
                name: "RestTimerTotalSeconds",
                table: "SharedSessions");
        }
    }
}
