using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Common;

// RN-09: próximas dosis por aplicar. Por cada animal y vacuna solo cuenta la
// última aplicación: si tiene próxima dosis, está pendiente; aplicar la vacuna
// de nuevo la cumple. La usan Sanidad (HU-27) y las alertas (HU-40).
public static class PendientesSanidad
{
    // Ordenadas por fecha de próxima dosis, de la más antigua a la más reciente.
    public static List<PendienteResponse> Calcular(IEnumerable<Vacunacion> vacunaciones)
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
