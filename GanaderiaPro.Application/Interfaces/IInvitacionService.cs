using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface IInvitacionService
{
    Task<InvitacionResponse> ObtenerAsync(string codigo);
    Task AceptarAsync(string codigo, AceptarInvitacionRequest request);
}
