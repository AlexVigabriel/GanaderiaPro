using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

[ApiController]
[Route("api/animales")]
[Authorize]
public class AnimalesController : ControllerBase
{
    private readonly IAnimalService _animalService;

    public AnimalesController(IAnimalService animalService)
    {
        _animalService = animalService;
    }

    [HttpPost]
    public async Task<ActionResult<AnimalResponse>> Registrar(RegistrarAnimalRequest request)
    {
        try
        {
            var animal = await _animalService.RegistrarAsync(request);
            return Created($"api/animales/{animal.Id}", animal);
        }
        catch (ReglaDeNegocioException ex)
        {
            return BadRequest(new { mensaje = ex.Message });
        }
    }

    // HU-66: carga múltiple. Responde 200 aunque haya filas rechazadas:
    // el detalle de qué se registró y qué no va en el cuerpo.
    [HttpPost("lote")]
    public async Task<ActionResult<RegistrarLoteResponse>> RegistrarLote(List<RegistrarAnimalRequest> filas)
    {
        try
        {
            return Ok(await _animalService.RegistrarLoteAsync(filas));
        }
        catch (ReglaDeNegocioException ex)
        {
            return BadRequest(new { mensaje = ex.Message });
        }
    }

    // HU-67: conteos para las tarjetas del listado.
    [HttpGet("resumen")]
    public async Task<ActionResult<ResumenAnimalesResponse>> ObtenerResumen() =>
        Ok(await _animalService.ObtenerResumenAsync());

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<AnimalResponse>>> Buscar(
        [FromQuery] string? busqueda,
        [FromQuery] EstadoAnimal? estado,
        [FromQuery] SexoAnimal? sexo,
        [FromQuery] string? raza,
        [FromQuery] CategoriaAnimal? categoria)
    {
        var animales = await _animalService.BuscarAsync(busqueda, estado, sexo, raza, categoria);
        return Ok(animales);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<AnimalResponse>> ObtenerPorId(Guid id)
    {
        try
        {
            return Ok(await _animalService.ObtenerPorIdAsync(id));
        }
        catch (RecursoNoEncontradoException ex)
        {
            return NotFound(new { mensaje = ex.Message });
        }
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<AnimalResponse>> Editar(Guid id, RegistrarAnimalRequest request)
    {
        try
        {
            return Ok(await _animalService.EditarAsync(id, request));
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

    // HU-54: baja por venta o fallecimiento.
    [HttpPost("{id:guid}/baja")]
    public async Task<ActionResult<AnimalResponse>> RegistrarBaja(Guid id, RegistrarBajaRequest request)
    {
        try
        {
            return Ok(await _animalService.RegistrarBajaAsync(id, request));
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

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Eliminar(Guid id)
    {
        try
        {
            await _animalService.EliminarAsync(id);
            return NoContent();
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
