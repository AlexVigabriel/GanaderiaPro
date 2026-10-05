namespace GanaderiaPro.Domain.Entities;

// Roles predefinidos del MVP (backlog, sección 5). Los roles personalizados
// (HU-33) son de la Release 2.
public enum RolUsuario
{
    Propietario,
    Socio,
    Veterinario,
    EncargadoCorrales,
    EncargadoIngreso
}

// HU-32: un colaborador invitado queda Pendiente hasta su primer inicio de
// sesión. Inactivo: el propietario le quitó el acceso.
public enum EstadoUsuario
{
    Pendiente,
    Activo,
    Inactivo
}

public class Usuario
{
    // Roles que se asignan a un colaborador (los socios son la HU-29).
    public static readonly IReadOnlySet<RolUsuario> RolesDeColaborador =
        new HashSet<RolUsuario> { RolUsuario.Veterinario, RolUsuario.EncargadoCorrales, RolUsuario.EncargadoIngreso };

    public Guid Id { get; set; }

    public Guid RanchoId { get; set; }
    public Rancho? Rancho { get; set; }

    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;

    // Vacío mientras el colaborador no aceptó la invitación.
    public string PasswordHash { get; set; } = string.Empty;
    public RolUsuario Rol { get; set; } = RolUsuario.Socio;
    public EstadoUsuario Estado { get; set; } = EstadoUsuario.Pendiente;
    public DateTime FechaRegistro { get; set; }
    public DateTime? UltimoAcceso { get; set; }

    // HU-52: va en cada token. Al cerrar sesión se incrementa y todos los
    // tokens emitidos antes dejan de servir.
    public int VersionSesion { get; set; }

    public bool EsColaborador => RolesDeColaborador.Contains(Rol);
}
