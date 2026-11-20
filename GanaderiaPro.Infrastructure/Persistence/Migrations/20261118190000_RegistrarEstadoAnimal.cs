using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    public partial class RegistrarEstadoAnimal : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "PartoRegistradoPorId",
                table: "Preneces",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "EventosEstadoAnimal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AnimalId = table.Column<Guid>(type: "uuid", nullable: false),
                    EstadoAnterior = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    EstadoNuevo = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    FechaEvento = table.Column<DateOnly>(type: "date", nullable: false),
                    FechaRegistro = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UsuarioId = table.Column<Guid>(type: "uuid", nullable: true),
                    Observacion = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EventosEstadoAnimal", x => x.Id);
                    table.ForeignKey(
                        name: "FK_EventosEstadoAnimal_Animales_AnimalId",
                        column: x => x.AnimalId,
                        principalTable: "Animales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_EventosEstadoAnimal_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_EventosEstadoAnimal_AnimalId_FechaEvento_FechaRegistro",
                table: "EventosEstadoAnimal",
                columns: new[] { "AnimalId", "FechaEvento", "FechaRegistro" });

            migrationBuilder.CreateIndex(
                name: "IX_EventosEstadoAnimal_UsuarioId",
                table: "EventosEstadoAnimal",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_Preneces_PartoRegistradoPorId",
                table: "Preneces",
                column: "PartoRegistradoPorId");

            migrationBuilder.AddForeignKey(
                name: "FK_Preneces_Usuarios_PartoRegistradoPorId",
                table: "Preneces",
                column: "PartoRegistradoPorId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Preneces_Usuarios_PartoRegistradoPorId",
                table: "Preneces");

            migrationBuilder.DropTable(name: "EventosEstadoAnimal");

            migrationBuilder.DropIndex(
                name: "IX_Preneces_PartoRegistradoPorId",
                table: "Preneces");

            migrationBuilder.DropColumn(
                name: "PartoRegistradoPorId",
                table: "Preneces");
        }
    }
}
