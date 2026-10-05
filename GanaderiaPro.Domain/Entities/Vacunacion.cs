namespace GanaderiaPro.Domain.Entities;

// HU-26: aplicación de una vacuna a un animal. Si tiene próxima dosis, queda
// pendiente hasta que se registre una aplicación posterior de la misma vacuna.
public class Vacunacion
{
    public Guid Id { get; set; }

    public Guid AnimalId { get; set; }
    public Animal? Animal { get; set; }

    public Guid VacunaId { get; set; }
    public Vacuna? Vacuna { get; set; }

    // Veterinario responsable: el usuario que la registró.
    public Guid VeterinarioId { get; set; }
    public Usuario? Veterinario { get; set; }

    public string Dosis { get; set; } = string.Empty;
    public DateOnly FechaAplicacion { get; set; }
    public DateOnly? FechaProximaDosis { get; set; }
    public string? Observacion { get; set; }
    public DateTime FechaRegistro { get; set; }
}
