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
        var pendientes = CalcularPendientes(vacunaciones);

        return new SanidadResumenResponse(
            Vacunados: vacunaciones.Select(v => v.AnimalId).Distinct().Count(),
            Pendientes: pendientes.Count,
            Vencidas: pendientes.Count(p => p.Vencida));
    }

    public async Task<IReadOnlyList<PendienteResponse>> ListarPendientesAsync() =>
        CalcularPendientes(await _vacunacionRepository.ListarDeActivosAsync(_currentUser.RanchoId));

    // Por cada animal y vacuna, solo cuenta la última aplicación: si tiene
    // próxima dosis, está pendiente. Aplicar la vacuna de nuevo la cumple.
    // Ordenadas por fecha de próxima dosis, de la más antigua a la más reciente.
    private static List<PendienteResponse> CalcularPendientes(IEnumerable<Vacunacion> vacunaciones)
    {
        var hoy = FechaRancho.Hoy();

        return vacunaciones
            .GroupBy(v => new { v.AnimalId, v.VacunaId })
            .Select(g => g.OrderByDescending(v => v.FechaAplicacion).ThenByDescending(v => v.FechaRegistro).First())
            .Where(v => v.FechaProximaDosis is not null)
            .OrderBy(v => v.FechaProximaDosis)
            .ThenBy(v => v.Animal?.Arete)
            .Select(v => new PendienteResponse(
                v.Id,
                v.AnimalId,
                v.Animal?.Arete ?? string.Empty,
                v.Animal?.Nombre,
                v.VacunaId,
                v.Vacuna?.Nombre ?? string.Empty,
                v.FechaAplicacion,
                v.FechaProximaDosis!.Value,
                v.FechaProximaDosis.Value < hoy))
            .ToList();
    }
}
