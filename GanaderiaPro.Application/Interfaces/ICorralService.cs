using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface ICorralService
{
    Task<CorralResponse> CrearAsync(CrearCorralRequest request);
    Task<IReadOnlyList<CorralResponse>> ListarAsync(bool incluirInactivos = false);
    Task<CorralResponse> EditarAsync(Guid id, EditarCorralRequest request);
    Task<CorralResponse> CambiarEstadoAsync(Guid id, bool activo);
    Task AsignarAnimalAsync(Guid animalId, Guid? corralId);
}
