using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AgregarPesajes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Pesajes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AnimalId = table.Column<Guid>(type: "uuid", nullable: false),
                    Fecha = table.Column<DateOnly>(type: "date", nullable: false),
                    Peso = table.Column<decimal>(type: "numeric(7,2)", precision: 7, scale: 2, nullable: false),
                    Observacion = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    FechaRegistro = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Pesajes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Pesajes_Animales_AnimalId",
                        column: x => x.AnimalId,
                        principalTable: "Animales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Pesajes_AnimalId_Fecha",
                table: "Pesajes",
                columns: new[] { "AnimalId", "Fecha" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Pesajes");
        }
    }
}
