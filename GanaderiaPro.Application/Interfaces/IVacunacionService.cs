using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface IVacunacionService
{
    Task<IReadOnlyList<VacunaResponse>> ListarVacunasAsync();
    Task<IReadOnlyList<VacunacionResponse>> RegistrarAsync(RegistrarVacunacionRequest request);
    Task<VacunacionResponse> EditarAsync(Guid id, EditarVacunacionRequest request);
    Task EliminarAsync(Guid id);
    Task<IReadOnlyList<VacunacionResponse>> ListarPorAnimalAsync(Guid animalId);
    Task<IReadOnlyList<VacunacionResponse>> ListarRecientesAsync();
}
