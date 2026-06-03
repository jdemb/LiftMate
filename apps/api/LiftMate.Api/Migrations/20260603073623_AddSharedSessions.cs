using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSharedSessions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "SharedSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TrainerUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    TraineeUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Version = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    ClosedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SharedSessions", x => x.Id);
                    table.CheckConstraint("CK_SharedSessions_Status", "[Status] IN ('active', 'completed', 'cancelled')");
                    table.ForeignKey(
                        name: "FK_SharedSessions_AspNetUsers_TraineeUserId",
                        column: x => x.TraineeUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SharedSessions_AspNetUsers_TrainerUserId",
                        column: x => x.TrainerUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SharedSessionValues",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SharedSessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExerciseName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    ExerciseType = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    SetIndex = table.Column<int>(type: "int", nullable: false),
                    Reps = table.Column<int>(type: "int", nullable: true),
                    Weight = table.Column<decimal>(type: "decimal(8,2)", precision: 8, scale: 2, nullable: true),
                    Seconds = table.Column<int>(type: "int", nullable: true),
                    UpdatedByUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: true),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SharedSessionValues", x => x.Id);
                    table.CheckConstraint("CK_SharedSessionValues_ExerciseType", "[ExerciseType] IN ('repsWeight', 'repsOnly', 'time')");
                    table.ForeignKey(
                        name: "FK_SharedSessionValues_AspNetUsers_UpdatedByUserId",
                        column: x => x.UpdatedByUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SharedSessionValues_SharedSessions_SharedSessionId",
                        column: x => x.SharedSessionId,
                        principalTable: "SharedSessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessions_Status",
                table: "SharedSessions",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessions_TraineeUserId",
                table: "SharedSessions",
                column: "TraineeUserId");

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessions_TrainerUserId",
                table: "SharedSessions",
                column: "TrainerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessionValues_ExerciseType",
                table: "SharedSessionValues",
                column: "ExerciseType");

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessionValues_SharedSessionId",
                table: "SharedSessionValues",
                column: "SharedSessionId");

            migrationBuilder.CreateIndex(
                name: "IX_SharedSessionValues_UpdatedByUserId",
                table: "SharedSessionValues",
                column: "UpdatedByUserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SharedSessionValues");

            migrationBuilder.DropTable(
                name: "SharedSessions");
        }
    }
}
