using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.DTOs;

// HU-56
public record RegistrarServicioRequest(DateOnly FechaServicio, string? Observacion = null);

public record RegistrarPartoRequest(DateOnly FechaParto);

// RC-10
public record RegistrarDiagnosticoPrenezRequest(DateOnly Fecha, DiagnosticoPrenez Resultado);

public record RegistrarAbortoRequest(DateOnly Fecha);

public record PrenezResponse(
    Guid Id,
    DateOnly FechaServicio,
    DateOnly FechaProbableParto,
    DateOnly? FechaParto,
    bool Abierta,
    string? Observacion,
    EstadoPrenez Estado,
    DiagnosticoPrenez? Diagnostico,
    DateOnly? FechaDiagnostico,
    DateOnly? FechaAborto);

// RN-10: hembras con parto probable dentro de los próximos días (o ya
// vencido sin registrar). La usan el tablero (HU-12) y las alertas (HU-40).
public record ProximaAParirResponse(Guid AnimalId, string Arete, string? Nombre, DateOnly FechaProbableParto, int DiasRestantes);
