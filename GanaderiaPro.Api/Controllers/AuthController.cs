using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Api.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("registrar")]
    [AllowAnonymous]
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

    // HU-52: cierra la sesión en el servidor; el token deja de servir.
    // Va sin [AllowAnonymous]: si estuviera en toda la clase anularía el [Authorize].
    [HttpPost("cerrar-sesion")]
    [Authorize]
    [SinModulo]
    public async Task<IActionResult> CerrarSesion([FromServices] ICurrentUserContext usuarioActual)
    {
        await _authService.CerrarSesionAsync(usuarioActual.UsuarioId);
        return NoContent();
    }

    [HttpPost("iniciar-sesion")]
    [AllowAnonymous]
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
