using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSharedSessionWorkoutSetStart : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "CompletedAt",
                table: "SharedSessionValues",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ExerciseOrder",
                table: "SharedSessionValues",
                type: "int",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddColumn<bool>(
                name: "IsDone",
                table: "SharedSessionValues",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "StartedByRole",
                table: "SharedSessions",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "trainer");

            migrationBuilder.AddColumn<string>(
                name: "StartedByUserId",
                table: "SharedSessions",
                type: "nvarchar(450)",
                maxLength: 450,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<Guid>(
                name: "WorkoutSetId",
                table: "SharedSessions",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.Sql("""
                UPDATE [SharedSessions]
                SET [StartedByUserId] = [TrainerUserId]
                WHERE [StartedByUserId] = ''
                """);

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessionValues_SharedSessionId_ExerciseOrder_SetIndex",
                table: "SharedSessionValues",
                columns: new[] { "SharedSessionId", "ExerciseOrder", "SetIndex" });

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessions_StartedByUserId",
                table: "SharedSessions",
                column: "StartedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessions_WorkoutSetId",
                table: "SharedSessions",
                column: "WorkoutSetId");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SharedSessions_StartedByRole",
                table: "SharedSessions",
                sql: "[StartedByRole] IN ('trainer', 'trainee')");

            migrationBuilder.AddForeignKey(
                name: "FK_SharedSessions_AspNetUsers_StartedByUserId",
                table: "SharedSessions",
                column: "StartedByUserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_SharedSessions_WorkoutSets_WorkoutSetId",
                table: "SharedSessions",
                column: "WorkoutSetId",
                principalTable: "WorkoutSets",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_SharedSessions_AspNetUsers_StartedByUserId",
                table: "SharedSessions");

            migrationBuilder.DropForeignKey(
                name: "FK_SharedSessions_WorkoutSets_WorkoutSetId",
                table: "SharedSessions");

            migrationBuilder.DropIndex(
                name: "IX_SharedSessionValues_SharedSessionId_ExerciseOrder_SetIndex",
                table: "SharedSessionValues");

            migrationBuilder.DropIndex(
                name: "IX_SharedSessions_StartedByUserId",
                table: "SharedSessions");

            migrationBuilder.DropIndex(
                name: "IX_SharedSessions_WorkoutSetId",
                table: "SharedSessions");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SharedSessions_StartedByRole",
                table: "SharedSessions");

            migrationBuilder.DropColumn(
                name: "CompletedAt",
                table: "SharedSessionValues");

            migrationBuilder.DropColumn(
                name: "ExerciseOrder",
                table: "SharedSessionValues");

            migrationBuilder.DropColumn(
                name: "IsDone",
                table: "SharedSessionValues");

            migrationBuilder.DropColumn(
                name: "StartedByRole",
                table: "SharedSessions");

            migrationBuilder.DropColumn(
                name: "StartedByUserId",
                table: "SharedSessions");

            migrationBuilder.DropColumn(
                name: "WorkoutSetId",
                table: "SharedSessions");
        }
    }
}
