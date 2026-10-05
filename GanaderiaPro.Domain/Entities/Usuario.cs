namespace GanaderiaPro.Domain.Entities;

public enum RolUsuario
{
    Propietario,
    Socio,
    Colaborador
}

public class Usuario
{
    public Guid Id { get; set; }

    public Guid RanchoId { get; set; }
    public Rancho? Rancho { get; set; }

    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public RolUsuario Rol { get; set; } = RolUsuario.Colaborador;
    public DateTime FechaRegistro { get; set; }
    public bool Activo { get; set; } = true;

    // HU-52: va en cada token. Al cerrar sesión se incrementa y todos los
    // tokens emitidos antes dejan de servir.
    public int VersionSesion { get; set; }
}
