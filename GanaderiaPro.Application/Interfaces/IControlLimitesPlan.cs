using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Domain.Planes;

namespace GanaderiaPro.Application.Interfaces;

// HU-58 / RN-11: único lugar donde se valida el límite del plan. Lo usan todos
// los puntos de alta (manual, carga múltiple, reactivaciones y, más adelante,
// la sincronización sin conexión).
public interface IControlLimitesPlan
{
    Task<UsoPlanResponse> ObtenerUsoAsync();

    // Lanza ReglaDeNegocioException si agregar [cantidad] supera el límite.
    Task VerificarAsync(RecursoPlan recurso, int cantidad = 1);

    // Lugares que quedan (null: sin límite).
    Task<int?> LugaresLibresAsync(RecursoPlan recurso);

    Task<string> MensajeLimiteAsync(RecursoPlan recurso);
}
