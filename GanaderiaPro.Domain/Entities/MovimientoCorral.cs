namespace GanaderiaPro.Domain.Entities;

// HU-22 y HU-25: cada cambio de corral de un animal queda en su historial.
// Los nombres se guardan tal como estaban, por si después se renombra el corral.
public class MovimientoCorral
{
    public Guid Id { get; set; }

    public Guid AnimalId { get; set; }
    public Animal? Animal { get; set; }

    // Null: el animal no estaba en ningún corral (origen) o salió de todos (destino).
    public Guid? CorralOrigenId { get; set; }
    public string? CorralOrigen { get; set; }
    public Guid? CorralDestinoId { get; set; }
    public string? CorralDestino { get; set; }

    public DateTime Fecha { get; set; }

    public Guid UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }
}
