namespace GanaderiaPro.Application.DTOs;

// HU-56
public record RegistrarServicioRequest(DateOnly FechaServicio, string? Observacion = null);

public record RegistrarPartoRequest(DateOnly FechaParto);

public record PrenezResponse(
    Guid Id,
    DateOnly FechaServicio,
    DateOnly FechaProbableParto,
    DateOnly? FechaParto,
    bool Abierta,
    string? Observacion);

// RN-10: hembras con parto probable dentro de los próximos días (o ya
// vencido sin registrar). La usan el tablero (HU-12) y las alertas (HU-40).
public record ProximaAParirResponse(Guid AnimalId, string Arete, string? Nombre, DateOnly FechaProbableParto, int DiasRestantes);
