using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class NotificacionRepository : INotificacionRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public NotificacionRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    // Incluye las agregadas en esta misma operación y todavía no guardadas,
    // para no crear dos veces la misma alerta.
    public async Task<bool> ExisteAsync(Guid usuarioId, string clave) =>
        _dbContext.Notificaciones.Local.Any(n => n.UsuarioId == usuarioId && n.Clave == clave) ||
        await _dbContext.Notificaciones.AnyAsync(n => n.UsuarioId == usuarioId && n.Clave == clave);

    public void Agregar(Notificacion notificacion) => _dbContext.Notificaciones.Add(notificacion);

    public Task<int> ContarNoLeidasAsync(Guid usuarioId) =>
        _dbContext.Notificaciones.CountAsync(n => n.UsuarioId == usuarioId && !n.Leida);

    // De la más reciente a la más antigua.
    public async Task<IReadOnlyList<Notificacion>> ListarAsync(Guid usuarioId, int maximo) =>
        await _dbContext.Notificaciones
            .Where(n => n.UsuarioId == usuarioId)
            .OrderByDescending(n => n.Fecha)
            .Take(maximo)
            .ToListAsync();

    public Task<Notificacion?> ObtenerAsync(Guid usuarioId, Guid id) =>
        _dbContext.Notificaciones.FirstOrDefaultAsync(n => n.UsuarioId == usuarioId && n.Id == id);

    public async Task<IReadOnlyList<Notificacion>> ListarNoLeidasAsync(Guid usuarioId) =>
        await _dbContext.Notificaciones.Where(n => n.UsuarioId == usuarioId && !n.Leida).ToListAsync();
}
