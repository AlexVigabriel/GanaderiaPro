using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IVacunacionRepository
{
    void Agregar(Vacunacion vacunacion);
    void Eliminar(Vacunacion vacunacion);
    Task<Vacunacion?> ObtenerPorIdAsync(Guid ranchoId, Guid id);
    Task<IReadOnlyList<Vacunacion>> ListarPorAnimalAsync(Guid animalId);
    Task<IReadOnlyList<Vacunacion>> ListarRecientesAsync(Guid ranchoId, int cantidad);
    Task<IReadOnlyList<Vacuna>> ListarVacunasAsync();
    Task<Vacuna?> ObtenerVacunaAsync(Guid id);
}
