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

    // Del más reciente al más antiguo.
    public async Task<IReadOnlyList<Tratamiento>> ListarPorAnimalAsync(Guid animalId) =>
        await _dbContext.Tratamientos
            .Include(t => t.Veterinario)
            .Where(t => t.AnimalId == animalId)
            .OrderByDescending(t => t.FechaInicio)
            .ThenByDescending(t => t.FechaRegistro)
            .ToListAsync();
}
