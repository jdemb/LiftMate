using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkoutSets : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "WorkoutSets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TrainerUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WorkoutSets", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WorkoutSets_AspNetUsers_TrainerUserId",
                        column: x => x.TrainerUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "WorkoutSetAssignments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    WorkoutSetId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TraineeUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    AssignedByTrainerUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    AssignedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WorkoutSetAssignments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WorkoutSetAssignments_AspNetUsers_TraineeUserId",
                        column: x => x.TraineeUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_WorkoutSetAssignments_WorkoutSets_WorkoutSetId",
                        column: x => x.WorkoutSetId,
                        principalTable: "WorkoutSets",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "WorkoutSetRows",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    WorkoutSetId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExerciseOrder = table.Column<int>(type: "int", nullable: false),
                    SetIndex = table.Column<int>(type: "int", nullable: false),
                    ExerciseName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    ExerciseType = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Reps = table.Column<int>(type: "int", nullable: true),
                    Weight = table.Column<decimal>(type: "decimal(8,2)", precision: 8, scale: 2, nullable: true),
                    Seconds = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WorkoutSetRows", x => x.Id);
                    table.CheckConstraint("CK_WorkoutSetRows_ExerciseType", "[ExerciseType] IN ('repsWeight', 'repsOnly', 'time')");
                    table.ForeignKey(
                        name: "FK_WorkoutSetRows_WorkoutSets_WorkoutSetId",
                        column: x => x.WorkoutSetId,
                        principalTable: "WorkoutSets",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutSetAssignments_TraineeUserId",
                table: "WorkoutSetAssignments",
                column: "TraineeUserId");

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutSetAssignments_WorkoutSetId",
                table: "WorkoutSetAssignments",
                column: "WorkoutSetId");

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutSetAssignments_WorkoutSetId_TraineeUserId",
                table: "WorkoutSetAssignments",
                columns: new[] { "WorkoutSetId", "TraineeUserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutSetRows_ExerciseType",
                table: "WorkoutSetRows",
                column: "ExerciseType");

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutSetRows_WorkoutSetId",
                table: "WorkoutSetRows",
                column: "WorkoutSetId");

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutSetRows_WorkoutSetId_ExerciseOrder_SetIndex",
                table: "WorkoutSetRows",
                columns: new[] { "WorkoutSetId", "ExerciseOrder", "SetIndex" });

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutSets_TrainerUserId",
                table: "WorkoutSets",
                column: "TrainerUserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "WorkoutSetAssignments");

            migrationBuilder.DropTable(
                name: "WorkoutSetRows");

            migrationBuilder.DropTable(
                name: "WorkoutSets");
        }
    }
}
