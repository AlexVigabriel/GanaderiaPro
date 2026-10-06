using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IPesajeRepository
{
    void Agregar(Pesaje pesaje);
    Task<IReadOnlyList<Pesaje>> ListarPorAnimalAsync(Guid animalId);
    Task<DateOnly?> ObtenerUltimaFechaAsync(Guid animalId);
    Task<bool> ExisteEnFechaAsync(Guid animalId, DateOnly fecha, Guid? excluirId = null);
    Task<Pesaje?> ObtenerPorIdAsync(Guid animalId, Guid pesajeId);
    void Eliminar(Pesaje pesaje);
}
