using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Planes;

namespace GanaderiaPro.Application.Interfaces;

// Entrega la estrategia de límites de un plan. La implementación real usa los
// números de RN-11; permite bajarlos en pruebas locales (ver LimitesPlanProvider).
public interface ILimitesPlanProvider
{
    ILimitesPlan Para(PlanSuscripcion plan);
}
