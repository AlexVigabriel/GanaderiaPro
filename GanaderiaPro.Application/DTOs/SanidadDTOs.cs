namespace GanaderiaPro.Application.DTOs;

// HU-27: indicadores del módulo Sanidad (RN-09).
public record SanidadResumenResponse(int Vacunados, int Pendientes, int Vencidas);

// Una próxima dosis por aplicar: la última aplicación de esa vacuna a ese
// animal y la fecha en que corresponde la siguiente.
public record PendienteResponse(
    Guid VacunacionId,
    Guid AnimalId,
    string Arete,
    string? NombreAnimal,
    Guid VacunaId,
    string Vacuna,
    DateOnly UltimaAplicacion,
    DateOnly FechaProximaDosis,
    bool Vencida);
