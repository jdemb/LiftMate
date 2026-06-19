using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkoutProgressProjection : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "WorkoutProgresses",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TraineeUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    WorkoutSetId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SourceSessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SourceCompletedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WorkoutProgresses", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WorkoutProgresses_WorkoutSets_WorkoutSetId",
                        column: x => x.WorkoutSetId,
                        principalTable: "WorkoutSets",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "WorkoutProgressValues",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    WorkoutProgressId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    WorkoutSetRowId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExerciseId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExerciseType = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Reps = table.Column<int>(type: "int", nullable: true),
                    Weight = table.Column<decimal>(type: "decimal(8,2)", precision: 8, scale: 2, nullable: true),
                    Seconds = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WorkoutProgressValues", x => x.Id);
                    table.CheckConstraint("CK_WorkoutProgressValues_ExerciseType", "[ExerciseType] IN ('repsWeight', 'repsOnly', 'time')");
                    table.ForeignKey(
                        name: "FK_WorkoutProgressValues_WorkoutProgresses_WorkoutProgressId",
                        column: x => x.WorkoutProgressId,
                        principalTable: "WorkoutProgresses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutProgresses_SourceSessionId",
                table: "WorkoutProgresses",
                column: "SourceSessionId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutProgresses_TraineeUserId_WorkoutSetId",
                table: "WorkoutProgresses",
                columns: new[] { "TraineeUserId", "WorkoutSetId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutProgresses_WorkoutSetId",
                table: "WorkoutProgresses",
                column: "WorkoutSetId");

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutProgressValues_ExerciseId",
                table: "WorkoutProgressValues",
                column: "ExerciseId");

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutProgressValues_WorkoutProgressId_WorkoutSetRowId",
                table: "WorkoutProgressValues",
                columns: new[] { "WorkoutProgressId", "WorkoutSetRowId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "WorkoutProgressValues");

            migrationBuilder.DropTable(
                name: "WorkoutProgresses");
        }
    }
}
