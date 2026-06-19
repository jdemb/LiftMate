using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddStableWorkoutIdentityAndSessionSnapshots : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ExerciseId",
                table: "WorkoutSetRows",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.Sql(
                """
                UPDATE workoutRow
                SET ExerciseId = exerciseGroup.ExerciseId
                FROM WorkoutSetRows AS workoutRow
                INNER JOIN (
                    SELECT WorkoutSetId, ExerciseOrder, MIN(Id) AS ExerciseId
                    FROM WorkoutSetRows
                    GROUP BY WorkoutSetId, ExerciseOrder
                ) AS exerciseGroup
                    ON exerciseGroup.WorkoutSetId = workoutRow.WorkoutSetId
                    AND exerciseGroup.ExerciseOrder = workoutRow.ExerciseOrder;
                """);

            migrationBuilder.AlterColumn<Guid>(
                name: "ExerciseId",
                table: "WorkoutSetRows",
                type: "uniqueidentifier",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uniqueidentifier",
                oldNullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ExerciseId",
                table: "SharedSessionValues",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "WorkoutSetRowId",
                table: "SharedSessionValues",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WorkoutSetName",
                table: "SharedSessions",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: false,
                defaultValue: "Trening");

            migrationBuilder.Sql(
                """
                UPDATE sessionRow
                SET WorkoutSetName = workoutSet.Name
                FROM SharedSessions AS sessionRow
                INNER JOIN WorkoutSets AS workoutSet
                    ON workoutSet.Id = sessionRow.WorkoutSetId;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutSetRows_WorkoutSetId_ExerciseId_SetIndex",
                table: "WorkoutSetRows",
                columns: new[] { "WorkoutSetId", "ExerciseId", "SetIndex" });

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessionValues_ExerciseId",
                table: "SharedSessionValues",
                column: "ExerciseId");

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessionValues_WorkoutSetRowId",
                table: "SharedSessionValues",
                column: "WorkoutSetRowId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_WorkoutSetRows_WorkoutSetId_ExerciseId_SetIndex",
                table: "WorkoutSetRows");

            migrationBuilder.DropIndex(
                name: "IX_SharedSessionValues_ExerciseId",
                table: "SharedSessionValues");

            migrationBuilder.DropIndex(
                name: "IX_SharedSessionValues_WorkoutSetRowId",
                table: "SharedSessionValues");

            migrationBuilder.DropColumn(
                name: "ExerciseId",
                table: "WorkoutSetRows");

            migrationBuilder.DropColumn(
                name: "ExerciseId",
                table: "SharedSessionValues");

            migrationBuilder.DropColumn(
                name: "WorkoutSetRowId",
                table: "SharedSessionValues");

            migrationBuilder.DropColumn(
                name: "WorkoutSetName",
                table: "SharedSessions");
        }
    }
}
