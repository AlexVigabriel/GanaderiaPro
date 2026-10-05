using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IRanchoRepository
{
    void Agregar(Rancho rancho);
    Task<Rancho?> ObtenerPorIdAsync(Guid id);
}
