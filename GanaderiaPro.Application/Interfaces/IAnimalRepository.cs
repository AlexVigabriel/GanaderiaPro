using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IAnimalRepository
{
    Task<bool> ExisteAreteAsync(Guid ranchoId, string arete);
    void Agregar(Animal animal);
    Task<IReadOnlyList<Animal>> BuscarAsync(Guid ranchoId, string? busqueda, EstadoAnimal estado, SexoAnimal? sexo, string? raza);
}
