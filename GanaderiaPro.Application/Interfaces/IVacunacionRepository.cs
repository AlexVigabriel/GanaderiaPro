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
    // Vacunaciones de los animales activos del rancho (con animal y vacuna).
    Task<IReadOnlyList<Vacunacion>> ListarDeActivosAsync(Guid ranchoId);
    Task<IReadOnlyList<Vacunacion>> ListarPorAnimalesYVacunaAsync(IReadOnlyList<Guid> animalIds, Guid vacunaId);
}
