namespace GanaderiaPro.Domain.Entities;

// HU-26: catálogo de vacunas. Para el Sprint 2 viene precargado; la gestión
// del catálogo es la HU-60 (Release 2).
public class Vacuna
{
    public Guid Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
}
