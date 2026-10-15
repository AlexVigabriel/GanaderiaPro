using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-56: preñez y parto de una hembra.
[ApiController]
[Route("api/animales/{animalId:guid}/preneces")]
[Authorize]
[Modulo(Modulo.Reproduccion)]
public class PrenecesController : ControllerBase
{
    private readonly IPrenezService _prenezService;

    public PrenecesController(IPrenezService prenezService)
    {
        _prenezService = prenezService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<PrenezResponse>>> Listar(Guid animalId)
    {
        try
        {
            return Ok(await _prenezService.ListarAsync(animalId));
        }
        catch (RecursoNoEncontradoException ex)
        {
            return NotFound(new { mensaje = ex.Message });
        }
    }

    [HttpPost]
    public async Task<ActionResult<PrenezResponse>> RegistrarServicio(Guid animalId, RegistrarServicioRequest request)
    {
        try
        {
            return Ok(await _prenezService.RegistrarServicioAsync(animalId, request));
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

    [HttpPost("{prenezId:guid}/parto")]
    public async Task<ActionResult<PrenezResponse>> RegistrarParto(Guid animalId, Guid prenezId, RegistrarPartoRequest request)
    {
        try
        {
            return Ok(await _prenezService.RegistrarPartoAsync(animalId, prenezId, request));
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
