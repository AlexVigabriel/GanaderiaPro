using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-23 y HU-24: corrales del rancho.
[ApiController]
[Route("api/corrales")]
[Authorize]
public class CorralesController : ControllerBase
{
    private readonly ICorralService _corralService;

    public CorralesController(ICorralService corralService)
    {
        _corralService = corralService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<CorralResponse>>> Listar([FromQuery] bool incluirInactivos = false) =>
        Ok(await _corralService.ListarAsync(incluirInactivos));

    [HttpPost]
    public Task<ActionResult> Crear(CrearCorralRequest request) =>
        Responder(async () => Ok(await _corralService.CrearAsync(request)));

    [HttpPut("{id:guid}")]
    public Task<ActionResult> Editar(Guid id, EditarCorralRequest request) =>
        Responder(async () => Ok(await _corralService.EditarAsync(id, request)));

    [HttpPost("{id:guid}/desactivar")]
    public Task<ActionResult> Desactivar(Guid id) =>
        Responder(async () => Ok(await _corralService.CambiarEstadoAsync(id, activo: false)));

    [HttpPost("{id:guid}/activar")]
    public Task<ActionResult> Activar(Guid id) =>
        Responder(async () => Ok(await _corralService.CambiarEstadoAsync(id, activo: true)));

    private async Task<ActionResult> Responder(Func<Task<ActionResult>> accion)
    {
        try
        {
            return await accion();
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
