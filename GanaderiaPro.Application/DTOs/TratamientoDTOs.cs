namespace GanaderiaPro.Application.DTOs;

// HU-57
public record RegistrarTratamientoRequest(
    string Motivo,
    string Medicamento,
    string Dosis,
    DateOnly FechaInicio,
    int DuracionDias,
    string? Observacion = null);

public record TratamientoResponse(
    Guid Id,
    string Motivo,
    string Medicamento,
    string Dosis,
    DateOnly FechaInicio,
    int DuracionDias,
    DateOnly FechaFin,
    bool EnCurso,
    string? Observacion,
    string Veterinario);
