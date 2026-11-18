using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-27: consultas del módulo Sanidad. Solo lee; el registro de
// vacunaciones está en VacunacionService.
public class SanidadService : ISanidadService
{
    private readonly IVacunacionRepository _vacunacionRepository;
    private readonly ICurrentUserContext _currentUser;

    public SanidadService(IVacunacionRepository vacunacionRepository, ICurrentUserContext currentUser)
    {
        _vacunacionRepository = vacunacionRepository;
        _currentUser = currentUser;
    }

    // RN-09: "Vacunados" son los animales activos con al menos una vacunación;
    // "Pendientes", las próximas dosis por aplicar (de ellas, "Vencidas" las
    // que ya pasaron de fecha).
    public async Task<SanidadResumenResponse> ObtenerResumenAsync()
    {
        var vacunaciones = await _vacunacionRepository.ListarDeActivosAsync(_currentUser.RanchoId);
        var pendientes = PendientesSanidad.Calcular(vacunaciones);

        return new SanidadResumenResponse(
            Vacunados: vacunaciones.Select(v => v.AnimalId).Distinct().Count(),
            Pendientes: pendientes.Count,
            Vencidas: pendientes.Count(p => p.Vencida));
    }

    public async Task<IReadOnlyList<PendienteResponse>> ListarPendientesAsync() =>
        PendientesSanidad.Calcular(await _vacunacionRepository.ListarDeActivosAsync(_currentUser.RanchoId));
}
