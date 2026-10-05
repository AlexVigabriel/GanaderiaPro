using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AgregarVersionSesion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "VersionSesion",
                table: "Usuarios",
                type: "integer",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "VersionSesion",
                table: "Usuarios");
        }
    }
}
