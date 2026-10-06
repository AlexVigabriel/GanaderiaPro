using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-26: vacunaciones y catálogo de vacunas.
[ApiController]
[Route("api")]
[Authorize]
[Modulo(Modulo.Sanidad)]
public class VacunacionesController : ControllerBase
{
    private readonly IVacunacionService _vacunacionService;

    public VacunacionesController(IVacunacionService vacunacionService)
    {
        _vacunacionService = vacunacionService;
    }

    [HttpGet("vacunas")]
    public async Task<ActionResult<IReadOnlyList<VacunaResponse>>> ListarVacunas() =>
        Ok(await _vacunacionService.ListarVacunasAsync());

    [HttpGet("vacunaciones")]
    public async Task<ActionResult<IReadOnlyList<VacunacionResponse>>> ListarRecientes() =>
        Ok(await _vacunacionService.ListarRecientesAsync());

    [HttpGet("animales/{animalId:guid}/vacunaciones")]
    public Task<ActionResult> ListarPorAnimal(Guid animalId) =>
        Responder(async () => Ok(await _vacunacionService.ListarPorAnimalAsync(animalId)));

    // Revisa repetidas antes de registrar (bloqueos y avisos a confirmar).
    [HttpPost("vacunaciones/verificar")]
    public Task<ActionResult> Verificar(RegistrarVacunacionRequest request) =>
        Responder(async () => Ok(await _vacunacionService.VerificarAsync(request)));

    [HttpPost("vacunaciones")]
    public Task<ActionResult> Registrar(RegistrarVacunacionRequest request) =>
        Responder(async () => Ok(await _vacunacionService.RegistrarAsync(request)));

    [HttpPut("vacunaciones/{id:guid}")]
    public Task<ActionResult> Editar(Guid id, EditarVacunacionRequest request) =>
        Responder(async () => Ok(await _vacunacionService.EditarAsync(id, request)));

    [HttpDelete("vacunaciones/{id:guid}")]
    public Task<ActionResult> Eliminar(Guid id) =>
        Responder(async () =>
        {
            await _vacunacionService.EliminarAsync(id);
            return NoContent();
        });

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
