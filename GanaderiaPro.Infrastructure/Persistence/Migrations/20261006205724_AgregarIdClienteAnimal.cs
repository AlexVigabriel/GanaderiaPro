using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AgregarIdClienteAnimal : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "IdCliente",
                table: "Animales",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Animales_RanchoId_IdCliente",
                table: "Animales",
                columns: new[] { "RanchoId", "IdCliente" },
                unique: true,
                filter: "\"IdCliente\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Animales_RanchoId_IdCliente",
                table: "Animales");

            migrationBuilder.DropColumn(
                name: "IdCliente",
                table: "Animales");
        }
    }
}
