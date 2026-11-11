using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IPrenezRepository
{
    void Agregar(Prenez prenez);
    Task<IReadOnlyList<Prenez>> ListarPorAnimalAsync(Guid animalId);
    Task<Prenez?> ObtenerPorIdAsync(Guid animalId, Guid prenezId);
    Task<IReadOnlyList<Prenez>> ListarAbiertasConPartoHastaAsync(Guid ranchoId, DateOnly hasta);
}
