using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.DTOs;

public record RegistrarAnimalRequest(string Arete, SexoAnimal Sexo, string Raza, decimal? Peso);

public record AnimalResponse(
    Guid Id,
    string Arete,
    SexoAnimal Sexo,
    string Raza,
    decimal? Peso,
    EstadoAnimal Estado,
    DateTime FechaRegistro);
