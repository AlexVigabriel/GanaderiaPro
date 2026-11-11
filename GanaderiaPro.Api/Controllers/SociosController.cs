using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-29 y HU-30: socios del rancho. Igual que los colaboradores, solo los
// gestiona el propietario (matriz de permisos, fila «Socios y colaboradores»).
[ApiController]
[Route("api/socios")]
[Authorize]
[Modulo(Modulo.Colaboradores)]
public class SociosController : ControllerBase
{
    private readonly ISocioService _socioService;

    public SociosController(ISocioService socioService)
    {
        _socioService = socioService;
    }

    [HttpGet]
    public Task<ActionResult> Listar() => Responder(async () => Ok(await _socioService.ListarAsync()));

    [HttpPost]
    public Task<ActionResult> Invitar(InvitarSocioRequest request) =>
        Responder(async () => Ok(await _socioService.InvitarAsync(request)));

    [HttpPost("{id:guid}/invitacion")]
    public Task<ActionResult> RegenerarInvitacion(Guid id) =>
        Responder(async () => Ok(await _socioService.RegenerarInvitacionAsync(id)));

    private async Task<ActionResult> Responder(Func<Task<ActionResult>> accion)
    {
        try
        {
            return await accion();
        }
        catch (AccesoDenegadoException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { mensaje = ex.Message });
        }
        catch (RecursoNoEncontradoException ex)
        {
            return NotFound(new { mensaje = ex.Message });
        }
        catch (ReglaDeNegocioException ex)
        {
            return BadRequest(new { mensaje = ex.Message });
        }
    }
}
