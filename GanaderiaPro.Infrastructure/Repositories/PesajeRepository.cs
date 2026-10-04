using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class PesajeRepository : IPesajeRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public PesajeRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public void Agregar(Pesaje pesaje) => _dbContext.Pesajes.Add(pesaje);

    // Del más reciente al más antiguo.
    public async Task<IReadOnlyList<Pesaje>> ListarPorAnimalAsync(Guid animalId) =>
        await _dbContext.Pesajes
            .Where(p => p.AnimalId == animalId)
            .OrderByDescending(p => p.Fecha)
            .ThenByDescending(p => p.FechaRegistro)
            .ToListAsync();

    public Task<bool> ExisteEnFechaAsync(Guid animalId, DateOnly fecha) =>
        _dbContext.Pesajes.AnyAsync(p => p.AnimalId == animalId && p.Fecha == fecha);

    public Task<DateOnly?> ObtenerUltimaFechaAsync(Guid animalId) =>
        _dbContext.Pesajes
            .Where(p => p.AnimalId == animalId)
            .MaxAsync(p => (DateOnly?)p.Fecha);
}
