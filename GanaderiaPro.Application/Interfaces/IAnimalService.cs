using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IAnimalService
{
    Task<AnimalResponse> RegistrarAsync(RegistrarAnimalRequest request);
    // maximoFilas: 500 en la carga múltiple (HU-66); la importación de Excel permite 1000 (HU-43.2).
    Task<RegistrarLoteResponse> RegistrarLoteAsync(IReadOnlyList<RegistrarAnimalRequest> filas, int maximoFilas = 500);
    Task<ResumenAnimalesResponse> ObtenerResumenAsync();
    Task<IReadOnlyList<AnimalResponse>> BuscarAsync(
        string? busqueda, EstadoAnimal? estado, SexoAnimal? sexo, string? raza, CategoriaAnimal? categoria = null);
    Task<AnimalResponse> ObtenerPorIdAsync(Guid id);
    Task<AnimalResponse> EditarAsync(Guid id, RegistrarAnimalRequest request);
    Task EliminarAsync(Guid id);
    Task<AnimalResponse> RegistrarBajaAsync(Guid id, CambiarEstadoRequest request);
    Task<AnimalResponse> CambiarEstadoAsync(Guid id, CambiarEstadoRequest request);
}
