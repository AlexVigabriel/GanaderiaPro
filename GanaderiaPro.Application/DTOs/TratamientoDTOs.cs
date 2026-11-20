using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.DTOs;

// HU-57 / RC-08
public record RegistrarTratamientoRequest(
    string Diagnostico,
    string Medicamento,
    string Dosis,
    DateOnly FechaInicio,
    int DuracionDias,
    string? Observacion = null);

// RC-09
public record RegistrarSeguimientoRequest(DateOnly Fecha, EvolucionTratamiento Evolucion, string? Nota = null);

public record FinalizarTratamientoRequest(DateOnly Fecha, ResultadoTratamiento Resultado);

public record SeguimientoResponse(Guid Id, DateOnly Fecha, EvolucionTratamiento Evolucion, string? Nota, string Usuario);

public record TratamientoResponse(
    Guid Id,
    Guid AnimalId,
    string Arete,
    string? NombreAnimal,
    string Diagnostico,
    string Medicamento,
    string Dosis,
    DateOnly FechaInicio,
    int DuracionDias,
    DateOnly FechaFin,
    bool EnCurso,
    EstadoTratamiento Estado,
    int DiaActual,
    ResultadoTratamiento? Resultado,
    DateOnly? FechaFinalizacion,
    string? Observacion,
    string Veterinario,
    IReadOnlyList<SeguimientoResponse> Seguimientos);
