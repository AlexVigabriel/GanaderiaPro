using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Planes;
using Microsoft.Extensions.Configuration;

namespace GanaderiaPro.Infrastructure.Planes;

// Usa los límites de RN-11. Solo para probar en una base local se pueden
// bajar con la configuración, por ejemplo:
//   dotnet user-secrets set "LimitesPlanPrueba:Basico:Animales" "5" --project GanaderiaPro.Api
// Sin esa clave (lo normal) valen siempre los números del plan.
public class LimitesPlanProvider : ILimitesPlanProvider
{
    private readonly IConfiguration _configuration;

    public LimitesPlanProvider(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public ILimitesPlan Para(PlanSuscripcion plan)
    {
        var estrategia = EstrategiasPlan.Para(plan);
        var ajustes = _configuration.GetSection($"LimitesPlanPrueba:{plan}");
        return ajustes.Exists() ? new LimitesDePrueba(estrategia, ajustes) : estrategia;
    }

    // Decora la estrategia real cambiando solo los límites indicados.
    private sealed class LimitesDePrueba : ILimitesPlan
    {
        private readonly ILimitesPlan _real;
        private readonly IConfigurationSection _ajustes;

        public LimitesDePrueba(ILimitesPlan real, IConfigurationSection ajustes)
        {
            _real = real;
            _ajustes = ajustes;
        }

        public PlanSuscripcion Plan => _real.Plan;
        public string Nombre => _real.Nombre;
        public string? PlanSiguiente => _real.PlanSiguiente;

        public int? Limite(RecursoPlan recurso) =>
            int.TryParse(_ajustes[recurso.ToString()], out var valor) ? valor : _real.Limite(recurso);
    }
}
