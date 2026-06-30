using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkoutSetRestSeconds : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "RestSeconds",
                table: "WorkoutSets",
                type: "int",
                nullable: false,
                defaultValue: 90);

            migrationBuilder.AddColumn<int>(
                name: "RestSeconds",
                table: "SharedSessions",
                type: "int",
                nullable: false,
                defaultValue: 90);

            migrationBuilder.AddCheckConstraint(
                name: "CK_WorkoutSets_RestSeconds",
                table: "WorkoutSets",
                sql: "[RestSeconds] BETWEEN 15 AND 600");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SharedSessions_RestSeconds",
                table: "SharedSessions",
                sql: "[RestSeconds] BETWEEN 15 AND 600");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_WorkoutSets_RestSeconds",
                table: "WorkoutSets");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SharedSessions_RestSeconds",
                table: "SharedSessions");

            migrationBuilder.DropColumn(
                name: "RestSeconds",
                table: "WorkoutSets");

            migrationBuilder.DropColumn(
                name: "RestSeconds",
                table: "SharedSessions");
        }
    }
}
