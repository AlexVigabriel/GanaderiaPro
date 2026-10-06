using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IAnimalService
{
    Task<AnimalResponse> RegistrarAsync(RegistrarAnimalRequest request);
    Task<RegistrarLoteResponse> RegistrarLoteAsync(IReadOnlyList<RegistrarAnimalRequest> filas);
    Task<ResumenAnimalesResponse> ObtenerResumenAsync();
    Task<IReadOnlyList<AnimalResponse>> BuscarAsync(
        string? busqueda, EstadoAnimal? estado, SexoAnimal? sexo, string? raza, CategoriaAnimal? categoria = null);
    Task<AnimalResponse> ObtenerPorIdAsync(Guid id);
    Task<AnimalResponse> EditarAsync(Guid id, RegistrarAnimalRequest request);
    Task EliminarAsync(Guid id);
    Task<AnimalResponse> RegistrarBajaAsync(Guid id, CambiarEstadoRequest request);
    Task<AnimalResponse> CambiarEstadoAsync(Guid id, CambiarEstadoRequest request);
}
