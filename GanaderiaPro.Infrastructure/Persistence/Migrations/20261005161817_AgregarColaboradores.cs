using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GanaderiaPro.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AgregarColaboradores : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // HU-32: "Activo" (sí/no) pasa a "Estado". Primero se crea Estado con
            // los datos de Activo y recién después se borra Activo: así ningún
            // usuario existente se queda sin poder iniciar sesión.
            migrationBuilder.AddColumn<string>(
                name: "Estado",
                table: "Usuarios",
                type: "character varying(15)",
                maxLength: 15,
                nullable: false,
                defaultValue: "Activo");

            migrationBuilder.Sql("UPDATE \"Usuarios\" SET \"Estado\" = 'Inactivo' WHERE \"Activo\" = FALSE;");

            migrationBuilder.DropColumn(
                name: "Activo",
                table: "Usuarios");

            // RN-02: el correo se guarda en minúsculas y no se repite aunque
            // cambien las mayúsculas.
            migrationBuilder.Sql("UPDATE \"Usuarios\" SET \"Email\" = lower(trim(\"Email\"));");
            migrationBuilder.Sql("CREATE UNIQUE INDEX \"IX_Usuarios_Email_SinMayusculas\" ON \"Usuarios\" (lower(\"Email\"));");

            migrationBuilder.AddColumn<DateTime>(
                name: "UltimoAcceso",
                table: "Usuarios",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Invitaciones",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UsuarioId = table.Column<Guid>(type: "uuid", nullable: false),
                    CodigoHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    FechaCreacion = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    FechaVencimiento = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    FechaUso = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Invitaciones", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Invitaciones_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Invitaciones_CodigoHash",
                table: "Invitaciones",
                column: "CodigoHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Invitaciones_UsuarioId",
                table: "Invitaciones",
                column: "UsuarioId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Invitaciones");

            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_Usuarios_Email_SinMayusculas\";");

            migrationBuilder.AddColumn<bool>(
                name: "Activo",
                table: "Usuarios",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.Sql("UPDATE \"Usuarios\" SET \"Activo\" = (\"Estado\" <> 'Inactivo');");

            migrationBuilder.DropColumn(
                name: "Estado",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "UltimoAcceso",
                table: "Usuarios");

        }
    }
}
