using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-32: enlace de invitación. Es público: el colaborador todavía no tiene
// contraseña. El código de la URL es la única credencial.
[ApiController]
[Route("api/invitaciones")]
[AllowAnonymous]
public class InvitacionesController : ControllerBase
{
    private readonly IInvitacionService _invitacionService;

    public InvitacionesController(IInvitacionService invitacionService)
    {
        _invitacionService = invitacionService;
    }

    [HttpGet("{codigo}")]
    public async Task<ActionResult<InvitacionResponse>> Obtener(string codigo)
    {
        try
        {
            return Ok(await _invitacionService.ObtenerAsync(codigo));
        }
        catch (ReglaDeNegocioException ex)
        {
            return BadRequest(new { mensaje = ex.Message });
        }
    }

    [HttpPost("{codigo}/aceptar")]
    public async Task<IActionResult> Aceptar(string codigo, AceptarInvitacionRequest request)
    {
        try
        {
            await _invitacionService.AceptarAsync(codigo, request);
            return NoContent();
        }
        catch (ReglaDeNegocioException ex)
        {
            return BadRequest(new { mensaje = ex.Message });
        }
    }
}
