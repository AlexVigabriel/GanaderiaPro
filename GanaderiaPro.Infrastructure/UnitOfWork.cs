using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Infrastructure.Persistence;

namespace GanaderiaPro.Infrastructure;

public class UnitOfWork : IUnitOfWork
{
    private readonly GanaderiaProDbContext _dbContext;

    public UnitOfWork(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public Task GuardarCambiosAsync() => _dbContext.SaveChangesAsync();
}
