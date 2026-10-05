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
    string? Observacion = null);

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
