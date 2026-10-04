namespace GanaderiaPro.Domain.Entities;

// HU-55: peso de un animal en una fecha. El historial queda completo; el peso
// actual del animal es el del pesaje más reciente.
public class Pesaje
{
    public Guid Id { get; set; }

    public Guid AnimalId { get; set; }
    public Animal? Animal { get; set; }

    public DateOnly Fecha { get; set; }
    public decimal Peso { get; set; }
    public string? Observacion { get; set; }
    public DateTime FechaRegistro { get; set; }
}
