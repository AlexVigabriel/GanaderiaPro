using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-57: tratamientos veterinarios de un animal.
[ApiController]
[Route("api/animales/{animalId:guid}/tratamientos")]
[Authorize]
[Modulo(Modulo.Sanidad)]
public class TratamientosController : ControllerBase
{
    private readonly ITratamientoService _tratamientoService;

    public TratamientosController(ITratamientoService tratamientoService)
    {
        _tratamientoService = tratamientoService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<TratamientoResponse>>> Listar(Guid animalId)
    {
        try
        {
            return Ok(await _tratamientoService.ListarAsync(animalId));
        }
        catch (RecursoNoEncontradoException ex)
        {
            return NotFound(new { mensaje = ex.Message });
        }
    }

    [HttpPost]
    public async Task<ActionResult<TratamientoResponse>> Registrar(Guid animalId, RegistrarTratamientoRequest request)
    {
        try
        {
            return Ok(await _tratamientoService.RegistrarAsync(animalId, request));
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
