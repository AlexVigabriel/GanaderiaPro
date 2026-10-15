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

    [HttpGet("no-leidas/cantidad")]
    [SinModulo]
    public async Task<ActionResult<object>> CantidadNoLeidas() =>
        Ok(new { cantidad = await _notificacionService.ContarNoLeidasAsync() });
}
