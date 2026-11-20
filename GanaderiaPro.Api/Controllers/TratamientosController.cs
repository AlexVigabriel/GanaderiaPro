using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-57: tratamientos veterinarios de un animal. RC-09: seguimiento y finalización.
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
    public Task<ActionResult<IReadOnlyList<TratamientoResponse>>> Listar(Guid animalId) =>
        Ejecutar(() => _tratamientoService.ListarAsync(animalId));

    [HttpPost]
    public Task<ActionResult<TratamientoResponse>> Registrar(Guid animalId, RegistrarTratamientoRequest request) =>
        Ejecutar(() => _tratamientoService.RegistrarAsync(animalId, request));

    [HttpPost("{tratamientoId:guid}/seguimientos")]
    public Task<ActionResult<TratamientoResponse>> RegistrarSeguimiento(
        Guid animalId, Guid tratamientoId, RegistrarSeguimientoRequest request) =>
        Ejecutar(() => _tratamientoService.RegistrarSeguimientoAsync(animalId, tratamientoId, request));

    [HttpPost("{tratamientoId:guid}/finalizar")]
    public Task<ActionResult<TratamientoResponse>> Finalizar(Guid animalId, Guid tratamientoId, FinalizarTratamientoRequest request) =>
        Ejecutar(() => _tratamientoService.FinalizarAsync(animalId, tratamientoId, request));

    private async Task<ActionResult<T>> Ejecutar<T>(Func<Task<T>> accion)
    {
        try
        {
            return Ok(await accion());
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

// RC-09: tratamientos de todo el rancho, para la pantalla Sanidad.
[ApiController]
[Route("api/tratamientos")]
[Authorize]
[Modulo(Modulo.Sanidad)]
public class TratamientosRanchoController : ControllerBase
{
    private readonly ITratamientoService _tratamientoService;

    public TratamientosRanchoController(ITratamientoService tratamientoService)
    {
        _tratamientoService = tratamientoService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<TratamientoResponse>>> Listar([FromQuery] bool terminados = false) =>
        Ok(await _tratamientoService.ListarDelRanchoAsync(terminados));
}
