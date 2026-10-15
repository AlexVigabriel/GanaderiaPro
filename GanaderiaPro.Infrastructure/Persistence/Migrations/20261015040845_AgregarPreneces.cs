using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AgregarPreneces : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Preneces",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AnimalId = table.Column<Guid>(type: "uuid", nullable: false),
                    FechaServicio = table.Column<DateOnly>(type: "date", nullable: false),
                    FechaProbableParto = table.Column<DateOnly>(type: "date", nullable: false),
                    FechaParto = table.Column<DateOnly>(type: "date", nullable: true),
                    Observacion = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    FechaRegistro = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Preneces", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Preneces_Animales_AnimalId",
                        column: x => x.AnimalId,
                        principalTable: "Animales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Preneces_AnimalId_FechaServicio",
                table: "Preneces",
                columns: new[] { "AnimalId", "FechaServicio" });

            migrationBuilder.CreateIndex(
                name: "IX_Preneces_FechaProbableParto",
                table: "Preneces",
                column: "FechaProbableParto");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Preneces");
        }
    }
}
