using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddTraineeWeeklyStreaks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TraineeWeeklyStreaks",
                columns: table => new
                {
                    TraineeUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    LastActiveWeekStart = table.Column<DateOnly>(type: "date", nullable: true),
                    CurrentStreakAtLastActiveWeek = table.Column<int>(type: "int", nullable: false),
                    BestStreak = table.Column<int>(type: "int", nullable: false),
                    LastCompletedSessionAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CalculatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TraineeWeeklyStreaks", x => x.TraineeUserId);
                    table.CheckConstraint("CK_TraineeWeeklyStreaks_BestStreak", "[BestStreak] >= 0");
                    table.CheckConstraint("CK_TraineeWeeklyStreaks_CurrentStreak", "[CurrentStreakAtLastActiveWeek] >= 0");
                    table.ForeignKey(
                        name: "FK_TraineeWeeklyStreaks_AspNetUsers_TraineeUserId",
                        column: x => x.TraineeUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TraineeWeeklyStreaks");
        }
    }
}
