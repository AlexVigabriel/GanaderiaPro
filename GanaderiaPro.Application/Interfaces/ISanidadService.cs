using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface ISanidadService
{
    Task<SanidadResumenResponse> ObtenerResumenAsync();
    Task<IReadOnlyList<PendienteResponse>> ListarPendientesAsync();
}
