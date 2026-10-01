using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface IAuthService
{
    Task<RegistrarCuentaResponse> RegistrarAsync(RegistrarCuentaRequest request);
    Task<IniciarSesionResponse> IniciarSesionAsync(IniciarSesionRequest request);
}
