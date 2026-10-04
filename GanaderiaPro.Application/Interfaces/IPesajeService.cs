using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface IPesajeService
{
    Task<RegistrarPesajeResponse> RegistrarAsync(Guid animalId, RegistrarPesajeRequest request);
    Task<IReadOnlyList<PesajeResponse>> ListarAsync(Guid animalId);
    Task<RegistrarPesajeResponse> EditarAsync(Guid animalId, Guid pesajeId, RegistrarPesajeRequest request);
    Task<decimal?> EliminarAsync(Guid animalId, Guid pesajeId);
}
