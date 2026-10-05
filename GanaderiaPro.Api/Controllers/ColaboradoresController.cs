using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-32: colaboradores del rancho (solo el propietario).
[ApiController]
[Route("api/colaboradores")]
[Authorize]
public class ColaboradoresController : ControllerBase
{
    private readonly IColaboradorService _colaboradorService;

    public ColaboradoresController(IColaboradorService colaboradorService)
    {
        _colaboradorService = colaboradorService;
    }

    [HttpGet]
    public Task<ActionResult> Listar() => Responder(async () => Ok(await _colaboradorService.ListarAsync()));

    [HttpPost]
    public Task<ActionResult> Invitar(InvitarColaboradorRequest request) =>
        Responder(async () => Ok(await _colaboradorService.InvitarAsync(request)));

    [HttpPost("{id:guid}/invitacion")]
    public Task<ActionResult> RegenerarInvitacion(Guid id) =>
        Responder(async () => Ok(await _colaboradorService.RegenerarInvitacionAsync(id)));

    [HttpPut("{id:guid}/rol")]
    public Task<ActionResult> CambiarRol(Guid id, CambiarRolRequest request) =>
        Responder(async () => Ok(await _colaboradorService.CambiarRolAsync(id, request)));

    [HttpPost("{id:guid}/desactivar")]
    public Task<ActionResult> Desactivar(Guid id) =>
        Responder(async () => Ok(await _colaboradorService.CambiarEstadoAsync(id, activo: false)));

    [HttpPost("{id:guid}/activar")]
    public Task<ActionResult> Activar(Guid id) =>
        Responder(async () => Ok(await _colaboradorService.CambiarEstadoAsync(id, activo: true)));

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
