using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LiftMate.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddDisplayNameAndPairing : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DisplayName",
                table: "AspNetUsers",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: false,
                defaultValue: "");

            migrationBuilder.Sql(
                """
                UPDATE [AspNetUsers]
                SET [DisplayName] = LEFT(COALESCE(NULLIF([Email], ''), NULLIF([UserName], ''), 'LiftMate user'), 200)
                WHERE [DisplayName] = ''
                """);

            migrationBuilder.AddColumn<string>(
                name: "TrainerUserId",
                table: "AspNetUsers",
                type: "nvarchar(450)",
                maxLength: 450,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "TrainerInviteCodes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(6)", maxLength: 6, nullable: false),
                    TrainerUserId = table.Column<string>(type: "nvarchar(450)", maxLength: 450, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    LastUsedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrainerInviteCodes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TrainerInviteCodes_AspNetUsers_TrainerUserId",
                        column: x => x.TrainerUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AspNetUsers_TrainerUserId",
                table: "AspNetUsers",
                column: "TrainerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_TrainerInviteCodes_Code",
                table: "TrainerInviteCodes",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TrainerInviteCodes_TrainerUserId",
                table: "TrainerInviteCodes",
                column: "TrainerUserId",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_AspNetUsers_AspNetUsers_TrainerUserId",
                table: "AspNetUsers",
                column: "TrainerUserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_AspNetUsers_AspNetUsers_TrainerUserId",
                table: "AspNetUsers");

            migrationBuilder.DropTable(
                name: "TrainerInviteCodes");

            migrationBuilder.DropIndex(
                name: "IX_AspNetUsers_TrainerUserId",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "DisplayName",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "TrainerUserId",
                table: "AspNetUsers");
        }
    }
}
