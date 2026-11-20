namespace GanaderiaPro.Application.DTOs;

// HU-22: un evento de la línea de tiempo del animal.
// Tipo: Vacunacion, Tratamiento, SeguimientoTratamiento, FinTratamiento, Pesaje,
// Servicio, DiagnosticoPrenez, Parto, Aborto, MovimientoCorral, Baja o Reactivacion.
// Categoria (RC-11, para filtrar): Sanidad, Reproduccion, Pesajes, Corrales o Estado.
// Usuario: quien lo registró (null en registros anteriores a esta versión).
public record EventoHistorialResponse(
    DateOnly Fecha,
    string Tipo,
    string Categoria,
    string Descripcion,
    string? Usuario,
    DateTime FechaRegistro);

public static class CategoriaEvento
{
    public const string Sanidad = "Sanidad";
    public const string Reproduccion = "Reproduccion";
    public const string Pesajes = "Pesajes";
    public const string Corrales = "Corrales";
    public const string Estado = "Estado";
}
