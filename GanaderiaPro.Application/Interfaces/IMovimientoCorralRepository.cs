using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IMovimientoCorralRepository
{
    void Agregar(MovimientoCorral movimiento);
    // Con el usuario que lo registró.
    Task<IReadOnlyList<MovimientoCorral>> ListarPorAnimalAsync(Guid animalId);
}
