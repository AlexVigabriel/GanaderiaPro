using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AgregarCorrales : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "CorralId",
                table: "Animales",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Corrales",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RanchoId = table.Column<Guid>(type: "uuid", nullable: false),
                    Nombre = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    Capacidad = table.Column<int>(type: "integer", nullable: false),
                    Activo = table.Column<bool>(type: "boolean", nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Corrales", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Corrales_Ranchos_RanchoId",
                        column: x => x.RanchoId,
                        principalTable: "Ranchos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Animales_CorralId",
                table: "Animales",
                column: "CorralId");

            migrationBuilder.CreateIndex(
                name: "IX_Corrales_RanchoId_Nombre",
                table: "Corrales",
                columns: new[] { "RanchoId", "Nombre" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Animales_Corrales_CorralId",
                table: "Animales",
                column: "CorralId",
                principalTable: "Corrales",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Animales_Corrales_CorralId",
                table: "Animales");

            migrationBuilder.DropTable(
                name: "Corrales");

            migrationBuilder.DropIndex(
                name: "IX_Animales_CorralId",
                table: "Animales");

            migrationBuilder.DropColumn(
                name: "CorralId",
                table: "Animales");
        }
    }
}
