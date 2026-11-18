using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface ISocioService
{
    Task<IReadOnlyList<ColaboradorResponse>> ListarAsync();
    Task<InvitacionCreadaResponse> InvitarAsync(InvitarSocioRequest request);
    Task<InvitacionCreadaResponse> RegenerarInvitacionAsync(Guid socioId);
}
