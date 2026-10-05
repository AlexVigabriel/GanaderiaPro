namespace GanaderiaPro.Application.DTOs;

public record VacunaResponse(Guid Id, string Nombre);

// HU-26: una misma aplicación puede registrarse para varios animales (por
// ejemplo, todo el rodeo vacunado el mismo día).
public record RegistrarVacunacionRequest(
    IReadOnlyList<Guid> AnimalIds,
    Guid VacunaId,
    string Dosis,
    DateOnly FechaAplicacion,
    DateOnly? FechaProximaDosis = null,
    string? Observacion = null,
    // true cuando el usuario ya vio los avisos (vacuna programada o reciente)
    // y decidió vacunar igual.
    bool Confirmado = false);

// Un animal que no se puede vacunar (bloqueo) o que conviene revisar (aviso).
public record AvisoVacunacion(Guid AnimalId, string Arete, string Motivo);

public record VerificacionVacunacionResponse(
    IReadOnlyList<AvisoVacunacion> Bloqueos,
    IReadOnlyList<AvisoVacunacion> Avisos);

public record EditarVacunacionRequest(
    Guid VacunaId,
    string Dosis,
    DateOnly FechaAplicacion,
    DateOnly? FechaProximaDosis = null,
    string? Observacion = null);

public record VacunacionResponse(
    Guid Id,
    Guid AnimalId,
    string Arete,
    string? NombreAnimal,
    Guid VacunaId,
    string Vacuna,
    string Dosis,
    DateOnly FechaAplicacion,
    DateOnly? FechaProximaDosis,
    string? Observacion,
    string Veterinario);
