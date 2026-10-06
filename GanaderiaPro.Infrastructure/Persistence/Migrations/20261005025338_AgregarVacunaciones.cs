using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AgregarVacunaciones : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Vacunas",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Nombre = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Vacunas", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Vacunaciones",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AnimalId = table.Column<Guid>(type: "uuid", nullable: false),
                    VacunaId = table.Column<Guid>(type: "uuid", nullable: false),
                    VeterinarioId = table.Column<Guid>(type: "uuid", nullable: false),
                    Dosis = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    FechaAplicacion = table.Column<DateOnly>(type: "date", nullable: false),
                    FechaProximaDosis = table.Column<DateOnly>(type: "date", nullable: true),
                    Observacion = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    FechaRegistro = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Vacunaciones", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Vacunaciones_Animales_AnimalId",
                        column: x => x.AnimalId,
                        principalTable: "Animales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Vacunaciones_Usuarios_VeterinarioId",
                        column: x => x.VeterinarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Vacunaciones_Vacunas_VacunaId",
                        column: x => x.VacunaId,
                        principalTable: "Vacunas",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "Vacunas",
                columns: new[] { "Id", "Nombre" },
                values: new object[,]
                {
                    { new Guid("8f1a2b01-0000-4000-8000-000000000001"), "Fiebre aftosa" },
                    { new Guid("8f1a2b01-0000-4000-8000-000000000002"), "Rabia bovina" },
                    { new Guid("8f1a2b01-0000-4000-8000-000000000003"), "Brucelosis" },
                    { new Guid("8f1a2b01-0000-4000-8000-000000000004"), "Carbunclo sintomático (mancha)" },
                    { new Guid("8f1a2b01-0000-4000-8000-000000000005"), "Clostridiosis polivalente" },
                    { new Guid("8f1a2b01-0000-4000-8000-000000000006"), "Leptospirosis" },
                    { new Guid("8f1a2b01-0000-4000-8000-000000000007"), "IBR-DVB (reproductiva)" },
                    { new Guid("8f1a2b01-0000-4000-8000-000000000008"), "Pasteurelosis" },
                    { new Guid("8f1a2b01-0000-4000-8000-000000000009"), "Carbunclo bacteridiano (ántrax)" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Vacunaciones_AnimalId_FechaAplicacion",
                table: "Vacunaciones",
                columns: new[] { "AnimalId", "FechaAplicacion" });

            migrationBuilder.CreateIndex(
                name: "IX_Vacunaciones_FechaProximaDosis",
                table: "Vacunaciones",
                column: "FechaProximaDosis");

            migrationBuilder.CreateIndex(
                name: "IX_Vacunaciones_VacunaId",
                table: "Vacunaciones",
                column: "VacunaId");

            migrationBuilder.CreateIndex(
                name: "IX_Vacunaciones_VeterinarioId",
                table: "Vacunaciones",
                column: "VeterinarioId");

            migrationBuilder.CreateIndex(
                name: "IX_Vacunas_Nombre",
                table: "Vacunas",
                column: "Nombre",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Vacunaciones");

            migrationBuilder.DropTable(
                name: "Vacunas");
        }
    }
}
