using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface IPesajeService
{
    Task<RegistrarPesajeResponse> RegistrarAsync(Guid animalId, RegistrarPesajeRequest request);
    Task<IReadOnlyList<PesajeResponse>> ListarAsync(Guid animalId);
}
