using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface IColaboradorService
{
    Task<IReadOnlyList<ColaboradorResponse>> ListarAsync();
    Task<InvitacionCreadaResponse> InvitarAsync(InvitarColaboradorRequest request);
    Task<InvitacionCreadaResponse> RegenerarInvitacionAsync(Guid colaboradorId);
    Task<ColaboradorResponse> CambiarRolAsync(Guid colaboradorId, CambiarRolRequest request);
    Task<ColaboradorResponse> CambiarEstadoAsync(Guid colaboradorId, bool activo);
}
