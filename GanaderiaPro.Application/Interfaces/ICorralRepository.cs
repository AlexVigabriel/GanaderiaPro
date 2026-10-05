using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface ICorralRepository
{
    void Agregar(Corral corral);
    Task<bool> ExisteNombreAsync(Guid ranchoId, string nombre, Guid? excluirId = null);
    Task<Corral?> ObtenerPorIdAsync(Guid ranchoId, Guid id);
    Task<IReadOnlyList<Corral>> ListarAsync(Guid ranchoId, bool incluirInactivos);
    // Cantidad de animales activos (sin bajas) por corral.
    Task<IReadOnlyDictionary<Guid, int>> ContarAnimalesActivosAsync(Guid ranchoId);
    Task<IReadOnlyList<Animal>> ListarAnimalesActivosAsync(Guid corralId);
}
