using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddTrainerGuidance : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TrainerGuidance",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TraineeUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    Type = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    ExerciseId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ExerciseName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    Fingerprint = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Message = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    EvidenceJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    ReadAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrainerGuidance", x => x.Id);
                    table.CheckConstraint("CK_TrainerGuidance_Type", "[Type] IN ('weight_stagnation', 'low_wellbeing')");
                });

            migrationBuilder.CreateIndex(
                name: "IX_TrainerGuidance_TraineeUserId_ReadAt_CreatedAt",
                table: "TrainerGuidance",
                columns: new[] { "TraineeUserId", "ReadAt", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_TrainerGuidance_TraineeUserId_Type_ExerciseId_Fingerprint",
                table: "TrainerGuidance",
                columns: new[] { "TraineeUserId", "Type", "ExerciseId", "Fingerprint" },
                unique: true,
                filter: "[ExerciseId] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TrainerGuidance");
        }
    }
}
