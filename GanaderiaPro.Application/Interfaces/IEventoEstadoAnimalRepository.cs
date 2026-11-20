using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IEventoEstadoAnimalRepository
{
    void Agregar(EventoEstadoAnimal evento);
    Task<IReadOnlyList<EventoEstadoAnimal>> ListarPorAnimalAsync(Guid animalId);
}
