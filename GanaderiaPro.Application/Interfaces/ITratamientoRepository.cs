using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface ITratamientoRepository
{
    void Agregar(Tratamiento tratamiento);
    void AgregarSeguimiento(SeguimientoTratamiento seguimiento);
    Task<IReadOnlyList<Tratamiento>> ListarPorAnimalAsync(Guid animalId);
    Task<Tratamiento?> ObtenerPorIdAsync(Guid animalId, Guid tratamientoId);
    Task<IReadOnlyList<Tratamiento>> ListarDelRanchoAsync(Guid ranchoId);
}
