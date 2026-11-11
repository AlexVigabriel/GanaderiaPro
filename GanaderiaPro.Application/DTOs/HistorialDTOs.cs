namespace GanaderiaPro.Application.DTOs;

// HU-22: un evento de la línea de tiempo del animal.
// Tipo: Vacunacion, Tratamiento, Pesaje, Servicio, Parto o MovimientoCorral.
// Usuario: quien lo registró (null en registros anteriores a esta versión).
public record EventoHistorialResponse(
    DateOnly Fecha,
    string Tipo,
    string Descripcion,
    string? Usuario,
    DateTime FechaRegistro);
