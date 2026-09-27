using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IAnimalService
{
    Task<AnimalResponse> RegistrarAsync(RegistrarAnimalRequest request);
    Task<IReadOnlyList<AnimalResponse>> BuscarAsync(string? busqueda, EstadoAnimal? estado, SexoAnimal? sexo, string? raza);
}
