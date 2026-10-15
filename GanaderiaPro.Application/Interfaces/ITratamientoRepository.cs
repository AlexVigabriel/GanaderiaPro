using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface ITratamientoRepository
{
    void Agregar(Tratamiento tratamiento);
    Task<IReadOnlyList<Tratamiento>> ListarPorAnimalAsync(Guid animalId);
}
