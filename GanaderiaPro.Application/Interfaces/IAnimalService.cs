using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IAnimalService
{
    Task<AnimalResponse> RegistrarAsync(RegistrarAnimalRequest request);
    Task<RegistrarLoteResponse> RegistrarLoteAsync(IReadOnlyList<RegistrarAnimalRequest> filas);
    Task<ResumenAnimalesResponse> ObtenerResumenAsync();
    Task<IReadOnlyList<AnimalResponse>> BuscarAsync(string? busqueda, EstadoAnimal? estado, SexoAnimal? sexo, string? raza);
    Task<AnimalResponse> ObtenerPorIdAsync(Guid id);
    Task<AnimalResponse> EditarAsync(Guid id, RegistrarAnimalRequest request);
    Task EliminarAsync(Guid id);
}
