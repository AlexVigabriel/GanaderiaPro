using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface INotificacionRepository
{
    void Agregar(Notificacion notificacion);
    Task<bool> ExisteAsync(Guid usuarioId, string clave);
    Task<int> ContarNoLeidasAsync(Guid usuarioId);
}
