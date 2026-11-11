using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AgregarHistorialAnimal : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "RegistradoPorId",
                table: "Preneces",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RegistradoPorId",
                table: "Pesajes",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "MovimientosCorral",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AnimalId = table.Column<Guid>(type: "uuid", nullable: false),
                    CorralOrigenId = table.Column<Guid>(type: "uuid", nullable: true),
                    CorralOrigen = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: true),
                    CorralDestinoId = table.Column<Guid>(type: "uuid", nullable: true),
                    CorralDestino = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: true),
                    Fecha = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UsuarioId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MovimientosCorral", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MovimientosCorral_Animales_AnimalId",
                        column: x => x.AnimalId,
                        principalTable: "Animales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_MovimientosCorral_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Preneces_RegistradoPorId",
                table: "Preneces",
                column: "RegistradoPorId");

            migrationBuilder.CreateIndex(
                name: "IX_Pesajes_RegistradoPorId",
                table: "Pesajes",
                column: "RegistradoPorId");

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosCorral_AnimalId_Fecha",
                table: "MovimientosCorral",
                columns: new[] { "AnimalId", "Fecha" });

            migrationBuilder.CreateIndex(
                name: "IX_MovimientosCorral_UsuarioId",
                table: "MovimientosCorral",
                column: "UsuarioId");

            migrationBuilder.AddForeignKey(
                name: "FK_Pesajes_Usuarios_RegistradoPorId",
                table: "Pesajes",
                column: "RegistradoPorId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Preneces_Usuarios_RegistradoPorId",
                table: "Preneces",
                column: "RegistradoPorId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Pesajes_Usuarios_RegistradoPorId",
                table: "Pesajes");

            migrationBuilder.DropForeignKey(
                name: "FK_Preneces_Usuarios_RegistradoPorId",
                table: "Preneces");

            migrationBuilder.DropTable(
                name: "MovimientosCorral");

            migrationBuilder.DropIndex(
                name: "IX_Preneces_RegistradoPorId",
                table: "Preneces");

            migrationBuilder.DropIndex(
                name: "IX_Pesajes_RegistradoPorId",
                table: "Pesajes");

            migrationBuilder.DropColumn(
                name: "RegistradoPorId",
                table: "Preneces");

            migrationBuilder.DropColumn(
                name: "RegistradoPorId",
                table: "Pesajes");
        }
    }
}
