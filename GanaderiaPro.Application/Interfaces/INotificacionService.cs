namespace GanaderiaPro.Application.Interfaces;

public interface INotificacionService
{
    // Revisa las alertas pendientes del rancho y cuenta las no leídas del usuario.
    Task<int> ContarNoLeidasAsync();
}
