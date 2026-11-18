using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface IPrenezService
{
    Task<IReadOnlyList<PrenezResponse>> ListarAsync(Guid animalId);
    Task<PrenezResponse> RegistrarServicioAsync(Guid animalId, RegistrarServicioRequest request);
    Task<PrenezResponse> RegistrarPartoAsync(Guid animalId, Guid prenezId, RegistrarPartoRequest request);
    Task<IReadOnlyList<ProximaAParirResponse>> ListarProximasAParirAsync(int dias = 30);
}
