namespace GanaderiaPro.Domain.Entities;

// HU-57: tratamiento veterinario de un animal (distinto de una vacunación).
public class Tratamiento
{
    public Guid Id { get; set; }

    public Guid AnimalId { get; set; }
    public Animal? Animal { get; set; }

    // Veterinario responsable: el usuario que lo registró.
    public Guid VeterinarioId { get; set; }
    public Usuario? Veterinario { get; set; }

    public string Motivo { get; set; } = string.Empty;
    public string Medicamento { get; set; } = string.Empty;
    public string Dosis { get; set; } = string.Empty;
    public DateOnly FechaInicio { get; set; }
    public int DuracionDias { get; set; }
    public string? Observacion { get; set; }
    public DateTime FechaRegistro { get; set; }

    // Último día del tratamiento (el de inicio cuenta como el primero).
    public DateOnly FechaFin => FechaInicio.AddDays(DuracionDias - 1);

    public bool EnCursoAl(DateOnly hoy) => hoy >= FechaInicio && hoy <= FechaFin;
}
