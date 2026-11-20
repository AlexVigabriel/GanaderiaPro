using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface ITratamientoService
{
    Task<IReadOnlyList<TratamientoResponse>> ListarAsync(Guid animalId);
    Task<TratamientoResponse> RegistrarAsync(Guid animalId, RegistrarTratamientoRequest request);
    Task<TratamientoResponse> RegistrarSeguimientoAsync(Guid animalId, Guid tratamientoId, RegistrarSeguimientoRequest request);
    Task<TratamientoResponse> FinalizarAsync(Guid animalId, Guid tratamientoId, FinalizarTratamientoRequest request);
    Task<IReadOnlyList<TratamientoResponse>> ListarDelRanchoAsync(bool terminados);
}
