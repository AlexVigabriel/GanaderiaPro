using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Api.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-40: notificaciones del usuario. Cada uno ve solo las suyas, sin importar el rol.
[ApiController]
[Route("api/notificaciones")]
[Authorize]
public class NotificacionesController : ControllerBase
{
    private readonly INotificacionService _notificacionService;

    public NotificacionesController(INotificacionService notificacionService)
    {
        _notificacionService = notificacionService;
    }

    // HU-41: de la más reciente a la más antigua.
    [HttpGet]
    [SinModulo]
    public async Task<ActionResult<IReadOnlyList<NotificacionResponse>>> Listar() =>
        Ok(await _notificacionService.ListarAsync());

    [HttpPost("{id:guid}/leida")]
    [SinModulo]
    public async Task<IActionResult> MarcarLeida(Guid id)
    {
        try
        {
            await _notificacionService.MarcarLeidaAsync(id);
            return NoContent();
        }
        catch (RecursoNoEncontradoException ex)
        {
            return NotFound(new { mensaje = ex.Message });
        }
    }

    [HttpPost("leidas")]
    [SinModulo]
    public async Task<IActionResult> MarcarTodasLeidas()
    {
        await _notificacionService.MarcarTodasLeidasAsync();
        return NoContent();
    }

    [HttpGet("no-leidas/cantidad")]
    [SinModulo]
    public async Task<ActionResult<object>> CantidadNoLeidas() =>
        Ok(new { cantidad = await _notificacionService.ContarNoLeidasAsync() });
}
