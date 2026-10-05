using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class RanchoRepository : IRanchoRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public RanchoRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public void Agregar(Rancho rancho) => _dbContext.Ranchos.Add(rancho);

    public Task<Rancho?> ObtenerPorIdAsync(Guid id) => _dbContext.Ranchos.FirstOrDefaultAsync(r => r.Id == id);
}
