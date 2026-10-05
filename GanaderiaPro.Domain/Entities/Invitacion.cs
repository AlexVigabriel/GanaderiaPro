namespace GanaderiaPro.Domain.Entities;

// HU-32: enlace para que un colaborador defina su contraseña. Se guarda solo
// el hash del código: aunque alguien lea la base, no puede usar el enlace.
public class Invitacion
{
    public Guid Id { get; set; }

    public Guid UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public string CodigoHash { get; set; } = string.Empty;
    public DateTime FechaCreacion { get; set; }
    public DateTime FechaVencimiento { get; set; }
    public DateTime? FechaUso { get; set; }

    public bool EstaVigente(DateTime ahora) => FechaUso is null && ahora < FechaVencimiento;
}
