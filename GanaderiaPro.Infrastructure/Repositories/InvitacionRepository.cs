using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class InvitacionRepository : IInvitacionRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public InvitacionRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public void Agregar(Invitacion invitacion) => _dbContext.Invitaciones.Add(invitacion);

    public Task<Invitacion?> ObtenerPorHashAsync(string codigoHash) =>
        _dbContext.Invitaciones
            .Include(i => i.Usuario)
            .ThenInclude(u => u!.Rancho)
            .FirstOrDefaultAsync(i => i.CodigoHash == codigoHash);

    public async Task<IReadOnlyList<Invitacion>> ListarSinUsarAsync(Guid usuarioId) =>
        await _dbContext.Invitaciones.Where(i => i.UsuarioId == usuarioId && i.FechaUso == null).ToListAsync();

    public async Task<IReadOnlyDictionary<Guid, DateTime>> VencimientosPendientesAsync(Guid ranchoId) =>
        await _dbContext.Invitaciones
            .Where(i => i.Usuario!.RanchoId == ranchoId && i.FechaUso == null)
            .GroupBy(i => i.UsuarioId)
            .Select(g => new { UsuarioId = g.Key, Vence = g.Max(i => i.FechaVencimiento) })
            .ToDictionaryAsync(x => x.UsuarioId, x => x.Vence);
}
