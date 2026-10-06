using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AmpliarFichaAnimal : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Color",
                table: "Animales",
                type: "character varying(40)",
                maxLength: 40,
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "FechaNacimiento",
                table: "Animales",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Nombre",
                table: "Animales",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Observaciones",
                table: "Animales",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "PesoNacimiento",
                table: "Animales",
                type: "numeric(7,2)",
                precision: 7,
                scale: 2,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Color",
                table: "Animales");

            migrationBuilder.DropColumn(
                name: "FechaNacimiento",
                table: "Animales");

            migrationBuilder.DropColumn(
                name: "Nombre",
                table: "Animales");

            migrationBuilder.DropColumn(
                name: "Observaciones",
                table: "Animales");

            migrationBuilder.DropColumn(
                name: "PesoNacimiento",
                table: "Animales");
        }
    }
}
