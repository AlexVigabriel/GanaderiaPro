using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IAnimalRepository
{
    Task<bool> ExisteAreteAsync(Guid ranchoId, string arete, Guid? excluirId = null);
    Task<Animal?> ObtenerPorIdAsync(Guid ranchoId, Guid id);
    void Agregar(Animal animal);
    void Eliminar(Animal animal);
    Task<IReadOnlyList<Animal>> BuscarAsync(Guid ranchoId, string? busqueda, EstadoAnimal estado, SexoAnimal? sexo, string? raza);
    Task<IReadOnlyList<ConteoAnimales>> ContarPorEstadoYSexoAsync(Guid ranchoId);

    // RN-04: las bajas no cuentan para el límite del plan.
    Task<int> ContarActivosAsync(Guid ranchoId);

    // RN-05: si tiene eventos (pesajes o vacunaciones) no se elimina.
    Task<bool> TieneEventosAsync(Guid animalId);
}
