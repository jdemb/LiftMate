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
