using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface INotificacionService
{
    // Revisa las alertas pendientes del rancho y cuenta las no leídas del usuario.
    Task<int> ContarNoLeidasAsync();

    // HU-41: centro de notificaciones del usuario actual.
    Task<IReadOnlyList<NotificacionResponse>> ListarAsync();
    Task MarcarLeidaAsync(Guid id);
    Task MarcarTodasLeidasAsync();
}
