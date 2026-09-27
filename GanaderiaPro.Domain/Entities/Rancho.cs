namespace GanaderiaPro.Domain.Entities;

public enum PlanSuscripcion
{
    Basico,
    Intermedio,
    Superior
}

public class Rancho
{
    public Guid Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public PlanSuscripcion Plan { get; set; } = PlanSuscripcion.Basico;
    public DateTime FechaRegistro { get; set; }
    public DateTime FechaFinPruebaGratuita { get; set; }

    public ICollection<Usuario> Usuarios { get; set; } = new List<Usuario>();
}
