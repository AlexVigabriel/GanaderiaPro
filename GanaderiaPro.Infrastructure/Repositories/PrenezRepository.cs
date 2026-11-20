using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class PrenezRepository : IPrenezRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public PrenezRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public void Agregar(Prenez prenez) => _dbContext.Preneces.Add(prenez);

    // De la más reciente a la más antigua.
    public async Task<IReadOnlyList<Prenez>> ListarPorAnimalAsync(Guid animalId) =>
        await _dbContext.Preneces
            .Include(p => p.RegistradoPor)
            .Include(p => p.PartoRegistradoPor)
            .Where(p => p.AnimalId == animalId)
            .OrderByDescending(p => p.FechaServicio)
            .ToListAsync();

    public Task<Prenez?> ObtenerPorIdAsync(Guid animalId, Guid prenezId) =>
        _dbContext.Preneces.FirstOrDefaultAsync(p => p.AnimalId == animalId && p.Id == prenezId);

    // Preñeces abiertas de hembras activas del rancho, con parto probable hasta la fecha dada.
    // RC-10: el diagnóstico «Vacía» y el aborto también la cierran.
    public async Task<IReadOnlyList<Prenez>> ListarAbiertasConPartoHastaAsync(Guid ranchoId, DateOnly hasta) =>
        await _dbContext.Preneces
            .Include(p => p.Animal)
            .Where(p => p.FechaParto == null
                && p.FechaAborto == null
                && p.Diagnostico != DiagnosticoPrenez.Vacia
                && p.FechaProbableParto <= hasta
                && p.Animal!.RanchoId == ranchoId
                && p.Animal.Estado == EstadoAnimal.Activo)
            .OrderBy(p => p.FechaProbableParto)
            .ToListAsync();
}
