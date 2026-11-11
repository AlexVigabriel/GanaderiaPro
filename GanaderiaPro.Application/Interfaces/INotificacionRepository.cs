using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface INotificacionRepository
{
    void Agregar(Notificacion notificacion);
    Task<bool> ExisteAsync(Guid usuarioId, string clave);
    // HU-38: si ya hay una con esa clave (como prefijo) desde la fecha dada.
    Task<bool> ExisteDesdeAsync(Guid usuarioId, string prefijoClave, DateTime desde);
    Task<int> ContarNoLeidasAsync(Guid usuarioId);

    // HU-41
    Task<IReadOnlyList<Notificacion>> ListarAsync(Guid usuarioId, int maximo);
    Task<Notificacion?> ObtenerAsync(Guid usuarioId, Guid id);
    Task<IReadOnlyList<Notificacion>> ListarNoLeidasAsync(Guid usuarioId);
}
