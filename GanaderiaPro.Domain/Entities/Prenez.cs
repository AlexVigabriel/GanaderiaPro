namespace GanaderiaPro.Domain.Entities;

// HU-56: servicio de una hembra y, cuando ocurre, su parto. Mientras no tiene
// fecha de parto, la preñez está abierta.
public class Prenez
{
    // RN-10: días de gestación de los bovinos.
    public const int DiasGestacion = 283;

    public Guid Id { get; set; }

    public Guid AnimalId { get; set; }
    public Animal? Animal { get; set; }

    public DateOnly FechaServicio { get; set; }
    // Se guarda para poder buscar rápido las próximas a parir (tablero y alertas).
    public DateOnly FechaProbableParto { get; set; }
    public DateOnly? FechaParto { get; set; }
    public string? Observacion { get; set; }
    public DateTime FechaRegistro { get; set; }

    public bool Abierta => FechaParto is null;

    public static DateOnly CalcularFechaProbableParto(DateOnly fechaServicio) => fechaServicio.AddDays(DiasGestacion);
}
