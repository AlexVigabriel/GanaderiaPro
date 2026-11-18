namespace GanaderiaPro.Domain.Entities;

// HU-22: conserva las bajas y reactivaciones incluso si luego se corrige el estado del animal.
public class EventoEstadoAnimal
{
    public Guid Id { get; set; }
    public Guid AnimalId { get; set; }
    public Animal? Animal { get; set; }
    public EstadoAnimal EstadoAnterior { get; set; }
    public EstadoAnimal EstadoNuevo { get; set; }
    public DateOnly FechaEvento { get; set; }
    public DateTime FechaRegistro { get; set; }
    public Guid? UsuarioId { get; set; }
    public Usuario? Usuario { get; set; }
    public string? Observacion { get; set; }
}
