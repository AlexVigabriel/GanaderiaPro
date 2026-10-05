using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Planes;

namespace GanaderiaPro.Application.Services;

// HU-58 / RN-11: controla los límites del plan del rancho actual.
public class ControlLimitesPlan : IControlLimitesPlan
{
    // Desde este porcentaje se avisa que el límite está cerca.
    public const int PorcentajeAviso = 90;

    private static readonly RolUsuario[] RolesColaborador = Usuario.RolesDeColaborador.ToArray();
    private static readonly RolUsuario[] RolesSocio = [RolUsuario.Socio];

    private readonly IRanchoRepository _ranchoRepository;
    private readonly IAnimalRepository _animalRepository;
    private readonly IUsuarioRepository _usuarioRepository;
    private readonly ILimitesPlanProvider _limitesProvider;
    private readonly ICurrentUserContext _currentUser;

    public ControlLimitesPlan(
        IRanchoRepository ranchoRepository,
        IAnimalRepository animalRepository,
        IUsuarioRepository usuarioRepository,
        ILimitesPlanProvider limitesProvider,
        ICurrentUserContext currentUser)
    {
        _ranchoRepository = ranchoRepository;
        _animalRepository = animalRepository;
        _usuarioRepository = usuarioRepository;
        _limitesProvider = limitesProvider;
        _currentUser = currentUser;
    }

    public async Task<UsoPlanResponse> ObtenerUsoAsync()
    {
        var limites = await LimitesDelRanchoAsync();
        var recursos = new List<UsoRecurso>();
        foreach (var recurso in Enum.GetValues<RecursoPlan>())
        {
            recursos.Add(Uso(recurso, await ContarAsync(recurso), limites.Limite(recurso)));
        }

        return new UsoPlanResponse(limites.Plan, limites.Nombre, limites.PlanSiguiente, recursos);
    }

    public async Task VerificarAsync(RecursoPlan recurso, int cantidad = 1)
    {
        var libres = await LugaresLibresAsync(recurso);
        if (libres is not null && cantidad > libres)
        {
            throw new ReglaDeNegocioException(await MensajeLimiteAsync(recurso));
        }
    }

    public async Task<int?> LugaresLibresAsync(RecursoPlan recurso)
    {
        var limite = (await LimitesDelRanchoAsync()).Limite(recurso);
        return limite is null ? null : Math.Max(0, limite.Value - await ContarAsync(recurso));
    }

    // Al propietario se le sugiere el plan siguiente; a los demás roles, que
    // le avisen al propietario (es quien puede cambiar de plan).
    public async Task<string> MensajeLimiteAsync(RecursoPlan recurso)
    {
        var limites = await LimitesDelRanchoAsync();
        var limite = limites.Limite(recurso);
        var nombre = NombreRecurso(recurso);

        if (_currentUser.Rol != RolUsuario.Propietario)
        {
            return $"El rancho llegó al límite de {limite} {nombre} de su plan {limites.Nombre}. Avisale al propietario.";
        }

        var sugerencia = limites.PlanSiguiente is null ? string.Empty : $" Para sumar más, pasate al plan {limites.PlanSiguiente}.";
        return $"Tu plan {limites.Nombre} permite hasta {limite} {nombre} y ya llegaste al límite.{sugerencia}";
    }

    private async Task<ILimitesPlan> LimitesDelRanchoAsync()
    {
        var rancho = await _ranchoRepository.ObtenerPorIdAsync(_currentUser.RanchoId)
            ?? throw new RecursoNoEncontradoException("No se encontró el rancho.");
        return _limitesProvider.Para(rancho.Plan);
    }

    private Task<int> ContarAsync(RecursoPlan recurso) => recurso switch
    {
        RecursoPlan.Animales => _animalRepository.ContarActivosAsync(_currentUser.RanchoId),
        RecursoPlan.Colaboradores => _usuarioRepository.ContarQueOcupanLugarAsync(_currentUser.RanchoId, RolesColaborador),
        _ => _usuarioRepository.ContarQueOcupanLugarAsync(_currentUser.RanchoId, RolesSocio),
    };

    private static UsoRecurso Uso(RecursoPlan recurso, int usados, int? limite)
    {
        if (limite is null or <= 0)
        {
            return new UsoRecurso(recurso, usados, limite, null, false, limite == 0);
        }

        var porcentaje = (int)Math.Round(usados * 100.0 / limite.Value);
        return new UsoRecurso(recurso, usados, limite, porcentaje, porcentaje >= PorcentajeAviso, usados >= limite);
    }

    private static string NombreRecurso(RecursoPlan recurso) => recurso switch
    {
        RecursoPlan.Animales => "animales activos",
        RecursoPlan.Colaboradores => "colaboradores",
        _ => "socios",
    };
}
