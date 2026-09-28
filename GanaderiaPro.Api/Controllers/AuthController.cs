using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

[ApiController]
[Route("api/auth")]
[AllowAnonymous]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("registrar")]
    public async Task<ActionResult<RegistrarCuentaResponse>> Registrar(RegistrarCuentaRequest request)
    {
        try
        {
            var respuesta = await _authService.RegistrarAsync(request);
            return Created($"api/auth/{respuesta.UsuarioId}", respuesta);
        }
        catch (ReglaDeNegocioException ex)
        {
            return BadRequest(new { mensaje = ex.Message });
        }
    }

    [HttpPost("iniciar-sesion")]
    public async Task<ActionResult<IniciarSesionResponse>> IniciarSesion(IniciarSesionRequest request)
    {
        try
        {
            var respuesta = await _authService.IniciarSesionAsync(request);
            return Ok(respuesta);
        }
        catch (ReglaDeNegocioException ex)
        {
            return BadRequest(new { mensaje = ex.Message });
        }
    }
}
