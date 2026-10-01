using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IAnimalRepository
{
    Task<bool> ExisteAreteAsync(Guid ranchoId, string arete, Guid? excluirId = null);
    Task<Animal?> ObtenerPorIdAsync(Guid ranchoId, Guid id);
    void Agregar(Animal animal);
    void Eliminar(Animal animal);
    Task<IReadOnlyList<Animal>> BuscarAsync(Guid ranchoId, string? busqueda, EstadoAnimal estado, SexoAnimal? sexo, string? raza);
}
