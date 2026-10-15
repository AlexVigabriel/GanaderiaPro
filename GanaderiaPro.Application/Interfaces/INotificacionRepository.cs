using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface INotificacionRepository
{
    void Agregar(Notificacion notificacion);
    Task<bool> ExisteAsync(Guid usuarioId, string clave);
    Task<int> ContarNoLeidasAsync(Guid usuarioId);

    // HU-41
    Task<IReadOnlyList<Notificacion>> ListarAsync(Guid usuarioId, int maximo);
    Task<Notificacion?> ObtenerAsync(Guid usuarioId, Guid id);
    Task<IReadOnlyList<Notificacion>> ListarNoLeidasAsync(Guid usuarioId);
}
