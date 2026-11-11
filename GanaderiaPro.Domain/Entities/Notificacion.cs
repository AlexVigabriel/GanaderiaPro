namespace GanaderiaPro.Domain.Entities;

// HU-40: tipos de alerta del criterio de aceptación.
public enum TipoNotificacion
{
    VacunaPendiente,
    CorralLleno,
    PartoProximo
}

// HU-40: alerta para un usuario. La clave identifica el hecho que la originó
// (por ejemplo, el parto de una preñez): cada usuario la recibe una sola vez.
public class Notificacion
{
    public Guid Id { get; set; }

    public Guid RanchoId { get; set; }

    public Guid UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }

    public TipoNotificacion Tipo { get; set; }
    public string Mensaje { get; set; } = string.Empty;

    // Registro relacionado, para llevar al usuario hasta él (HU-41).
    public string ReferenciaTipo { get; set; } = string.Empty;
    public Guid ReferenciaId { get; set; }

    public string Clave { get; set; } = string.Empty;
    public bool Leida { get; set; }
    public DateTime Fecha { get; set; }
}
