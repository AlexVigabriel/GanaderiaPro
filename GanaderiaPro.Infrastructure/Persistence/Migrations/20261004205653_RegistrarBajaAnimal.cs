using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RegistrarBajaAnimal : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateOnly>(
                name: "FechaBaja",
                table: "Animales",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ObservacionBaja",
                table: "Animales",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "FechaBaja",
                table: "Animales");

            migrationBuilder.DropColumn(
                name: "ObservacionBaja",
                table: "Animales");
        }
    }
}
