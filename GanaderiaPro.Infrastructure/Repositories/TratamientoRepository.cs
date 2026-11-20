using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class TratamientoRepository : ITratamientoRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public TratamientoRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public void Agregar(Tratamiento tratamiento) => _dbContext.Tratamientos.Add(tratamiento);

    public void AgregarSeguimiento(SeguimientoTratamiento seguimiento) => _dbContext.SeguimientosTratamiento.Add(seguimiento);

    // Del más reciente al más antiguo.
    public async Task<IReadOnlyList<Tratamiento>> ListarPorAnimalAsync(Guid animalId) =>
        await ConDetalle()
            .Where(t => t.AnimalId == animalId)
            .OrderByDescending(t => t.FechaInicio)
            .ThenByDescending(t => t.FechaRegistro)
            .ToListAsync();

    public Task<Tratamiento?> ObtenerPorIdAsync(Guid animalId, Guid tratamientoId) =>
        ConDetalle().FirstOrDefaultAsync(t => t.AnimalId == animalId && t.Id == tratamientoId);

    // RC-09: todos los tratamientos del rancho, con su animal.
    public async Task<IReadOnlyList<Tratamiento>> ListarDelRanchoAsync(Guid ranchoId) =>
        await ConDetalle()
            .Include(t => t.Animal)
            .Where(t => t.Animal!.RanchoId == ranchoId)
            .OrderByDescending(t => t.FechaInicio)
            .ThenByDescending(t => t.FechaRegistro)
            .ToListAsync();

    private IQueryable<Tratamiento> ConDetalle() =>
        _dbContext.Tratamientos
            .Include(t => t.Veterinario)
            .Include(t => t.FinalizadoPor)
            .Include(t => t.Seguimientos.OrderBy(s => s.Fecha))
                .ThenInclude(s => s.RegistradoPor)
            .AsSplitQuery();
}
