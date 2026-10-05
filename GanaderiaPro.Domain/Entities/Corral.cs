namespace GanaderiaPro.Domain.Entities;

// HU-23: corral del rancho. Cada animal está, como mucho, en un corral.
public class Corral
{
    public Guid Id { get; set; }

    public Guid RanchoId { get; set; }
    public Rancho? Rancho { get; set; }

    public string Nombre { get; set; } = string.Empty;
    public int Capacidad { get; set; }

    // HU-24: los corrales desactivados no se muestran en la vista por defecto.
    public bool Activo { get; set; } = true;
    public DateTime FechaCreacion { get; set; }
}
