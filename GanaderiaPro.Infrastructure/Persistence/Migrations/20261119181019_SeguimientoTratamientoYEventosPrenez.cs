using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SeguimientoTratamientoYEventosPrenez : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // RC-08: «Motivo» pasa a llamarse «Diagnóstico» sin perder lo cargado
            // (hasta 100 caracteres: en la base el más largo tenía 8).
            migrationBuilder.RenameColumn(
                name: "Motivo",
                table: "Tratamientos",
                newName: "Diagnostico");

            migrationBuilder.AlterColumn<string>(
                name: "Diagnostico",
                table: "Tratamientos",
                type: "character varying(100)",
                maxLength: 100,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(200)",
                oldMaxLength: 200);

            migrationBuilder.AlterColumn<string>(
                name: "Observacion",
                table: "Tratamientos",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(500)",
                oldMaxLength: 500,
                oldNullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "FechaFinalizacion",
                table: "Tratamientos",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "FinalizadoPorId",
                table: "Tratamientos",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Resultado",
                table: "Tratamientos",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Diagnostico",
                table: "Preneces",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "FechaAborto",
                table: "Preneces",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "FechaDiagnostico",
                table: "Preneces",
                type: "date",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "SeguimientosTratamiento",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TratamientoId = table.Column<Guid>(type: "uuid", nullable: false),
                    Fecha = table.Column<DateOnly>(type: "date", nullable: false),
                    Evolucion = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Nota = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    RegistradoPorId = table.Column<Guid>(type: "uuid", nullable: false),
                    FechaRegistro = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SeguimientosTratamiento", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SeguimientosTratamiento_Tratamientos_TratamientoId",
                        column: x => x.TratamientoId,
                        principalTable: "Tratamientos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SeguimientosTratamiento_Usuarios_RegistradoPorId",
                        column: x => x.RegistradoPorId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Tratamientos_FinalizadoPorId",
                table: "Tratamientos",
                column: "FinalizadoPorId");

            migrationBuilder.CreateIndex(
                name: "IX_SeguimientosTratamiento_RegistradoPorId",
                table: "SeguimientosTratamiento",
                column: "RegistradoPorId");

            migrationBuilder.CreateIndex(
                name: "IX_SeguimientosTratamiento_TratamientoId_Fecha",
                table: "SeguimientosTratamiento",
                columns: new[] { "TratamientoId", "Fecha" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Tratamientos_Usuarios_FinalizadoPorId",
                table: "Tratamientos",
                column: "FinalizadoPorId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Tratamientos_Usuarios_FinalizadoPorId",
                table: "Tratamientos");

            migrationBuilder.DropTable(
                name: "SeguimientosTratamiento");

            migrationBuilder.DropIndex(
                name: "IX_Tratamientos_FinalizadoPorId",
                table: "Tratamientos");

            migrationBuilder.DropColumn(
                name: "FechaFinalizacion",
                table: "Tratamientos");

            migrationBuilder.DropColumn(
                name: "FinalizadoPorId",
                table: "Tratamientos");

            migrationBuilder.DropColumn(
                name: "Resultado",
                table: "Tratamientos");

            migrationBuilder.DropColumn(
                name: "Diagnostico",
                table: "Preneces");

            migrationBuilder.DropColumn(
                name: "FechaAborto",
                table: "Preneces");

            migrationBuilder.DropColumn(
                name: "FechaDiagnostico",
                table: "Preneces");

            migrationBuilder.AlterColumn<string>(
                name: "Observacion",
                table: "Tratamientos",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "character varying(300)",
                oldMaxLength: 300,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Diagnostico",
                table: "Tratamientos",
                type: "character varying(200)",
                maxLength: 200,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(100)",
                oldMaxLength: 100);

            migrationBuilder.RenameColumn(
                name: "Diagnostico",
                table: "Tratamientos",
                newName: "Motivo");
        }
    }
}
