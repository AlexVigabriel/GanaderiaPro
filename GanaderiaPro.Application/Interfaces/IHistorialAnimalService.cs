using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface IHistorialAnimalService
{
    Task<IReadOnlyList<EventoHistorialResponse>> ListarAsync(Guid animalId);
}
