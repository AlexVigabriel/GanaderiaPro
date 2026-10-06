using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class CorralRepository : ICorralRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public CorralRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public void Agregar(Corral corral) => _dbContext.Corrales.Add(corral);

    // Sin distinguir mayúsculas: "Corral Norte" y "corral norte" son el mismo.
    public Task<bool> ExisteNombreAsync(Guid ranchoId, string nombre, Guid? excluirId = null) =>
        _dbContext.Corrales.AnyAsync(c =>
            c.RanchoId == ranchoId && c.Nombre.ToUpper() == nombre.ToUpper() && (excluirId == null || c.Id != excluirId));

    public Task<Corral?> ObtenerPorIdAsync(Guid ranchoId, Guid id) =>
        _dbContext.Corrales.FirstOrDefaultAsync(c => c.RanchoId == ranchoId && c.Id == id);

    public async Task<IReadOnlyList<Corral>> ListarAsync(Guid ranchoId, bool incluirInactivos) =>
        await _dbContext.Corrales
            .Where(c => c.RanchoId == ranchoId && (incluirInactivos || c.Activo))
            .OrderBy(c => c.Nombre)
            .ToListAsync();

    // RN-04: las bajas no ocupan lugar en el corral.
    public async Task<IReadOnlyDictionary<Guid, int>> ContarAnimalesActivosAsync(Guid ranchoId) =>
        await _dbContext.Animales
            .Where(a => a.RanchoId == ranchoId && a.Estado == EstadoAnimal.Activo && a.CorralId != null)
            .GroupBy(a => a.CorralId!.Value)
            .Select(g => new { CorralId = g.Key, Cantidad = g.Count() })
            .ToDictionaryAsync(x => x.CorralId, x => x.Cantidad);

    public async Task<IReadOnlyList<Animal>> ListarAnimalesActivosAsync(Guid corralId) =>
        await _dbContext.Animales
            .Where(a => a.CorralId == corralId && a.Estado == EstadoAnimal.Activo)
            .ToListAsync();
}
