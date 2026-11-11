namespace GanaderiaPro.Application.DTOs;

// HU-36.1 y HU-38: respuesta del asistente de consultas.
// Reconocida: false → Ejemplos trae preguntas soportadas.
// SinDatos: true → Responsable es quien debe registrar el dato (RN-12).
public record RespuestaAsistenteResponse(
    string Respuesta,
    bool Reconocida,
    bool SinDatos,
    string? Responsable,
    IReadOnlyList<string> Ejemplos);
