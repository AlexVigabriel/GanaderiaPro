using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface ITratamientoService
{
    Task<IReadOnlyList<TratamientoResponse>> ListarAsync(Guid animalId);
    Task<TratamientoResponse> RegistrarAsync(Guid animalId, RegistrarTratamientoRequest request);
}
