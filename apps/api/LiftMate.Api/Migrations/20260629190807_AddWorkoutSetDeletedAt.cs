using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkoutSetDeletedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "DeletedAt",
                table: "WorkoutSets",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_WorkoutSets_TrainerUserId_DeletedAt",
                table: "WorkoutSets",
                columns: new[] { "TrainerUserId", "DeletedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_WorkoutSets_TrainerUserId_DeletedAt",
                table: "WorkoutSets");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "WorkoutSets");
        }
    }
}
