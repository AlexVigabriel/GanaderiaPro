using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.DTOs;

public record RegistrarAnimalRequest(
    string Arete,
    SexoAnimal Sexo,
    string Raza,
    decimal? Peso,
    string? Nombre = null,
    DateOnly? FechaNacimiento = null,
    decimal? PesoNacimiento = null,
    string? Color = null,
    string? Observaciones = null);

public record AnimalResponse(
    Guid Id,
    string Arete,
    SexoAnimal Sexo,
    string Raza,
    decimal? Peso,
    EstadoAnimal Estado,
    DateTime FechaRegistro,
    string? Nombre,
    DateOnly? FechaNacimiento,
    decimal? PesoNacimiento,
    string? Color,
    string? Observaciones);

// HU-66: resultado de la carga múltiple. Las filas válidas se registran y
// las inválidas se informan con su número de fila y el motivo.
public record FilaRechazada(int Fila, string Arete, string Motivo);

public record RegistrarLoteResponse(IReadOnlyList<AnimalResponse> Registrados, IReadOnlyList<FilaRechazada> Rechazados);

// HU-67: conteos que se muestran arriba del listado.
public record ConteoAnimales(EstadoAnimal Estado, SexoAnimal Sexo, int Cantidad);

public record ResumenAnimalesResponse(int Activos, int HembrasActivas, int MachosActivos, int Vendidos, int Fallecidos);
