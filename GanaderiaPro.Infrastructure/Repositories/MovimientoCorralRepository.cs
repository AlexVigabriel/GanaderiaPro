using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class MovimientoCorralRepository : IMovimientoCorralRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public MovimientoCorralRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public void Agregar(MovimientoCorral movimiento) => _dbContext.MovimientosCorral.Add(movimiento);

    public async Task<IReadOnlyList<MovimientoCorral>> ListarPorAnimalAsync(Guid animalId) =>
        await _dbContext.MovimientosCorral
            .Include(m => m.Usuario)
            .Where(m => m.AnimalId == animalId)
            .OrderByDescending(m => m.Fecha)
            .ToListAsync();
}
