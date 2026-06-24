using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddPostWorkoutFeedback : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PostWorkoutFeedbacks",
                columns: table => new
                {
                    SharedSessionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    WellbeingRating = table.Column<int>(type: "int", nullable: false),
                    Comment = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    SubmittedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PostWorkoutFeedbacks", x => x.SharedSessionId);
                    table.CheckConstraint("CK_PostWorkoutFeedbacks_WellbeingRating", "[WellbeingRating] BETWEEN 1 AND 5");
                    table.ForeignKey(
                        name: "FK_PostWorkoutFeedbacks_SharedSessions_SharedSessionId",
                        column: x => x.SharedSessionId,
                        principalTable: "SharedSessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PostWorkoutFeedbacks");
        }
    }
}
