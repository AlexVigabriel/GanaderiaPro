using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-55: pesajes de un animal.
[ApiController]
[Route("api/animales/{animalId:guid}/pesajes")]
[Authorize]
public class PesajesController : ControllerBase
{
    private readonly IPesajeService _pesajeService;

    public PesajesController(IPesajeService pesajeService)
    {
        _pesajeService = pesajeService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<PesajeResponse>>> Listar(Guid animalId)
    {
        try
        {
            return Ok(await _pesajeService.ListarAsync(animalId));
        }
        catch (RecursoNoEncontradoException ex)
        {
            return NotFound(new { mensaje = ex.Message });
        }
    }

    [HttpPost]
    public async Task<ActionResult<RegistrarPesajeResponse>> Registrar(Guid animalId, RegistrarPesajeRequest request)
    {
        try
        {
            return Ok(await _pesajeService.RegistrarAsync(animalId, request));
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

    [HttpPut("{pesajeId:guid}")]
    public async Task<ActionResult<RegistrarPesajeResponse>> Editar(Guid animalId, Guid pesajeId, RegistrarPesajeRequest request)
    {
        try
        {
            return Ok(await _pesajeService.EditarAsync(animalId, pesajeId, request));
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

    [HttpDelete("{pesajeId:guid}")]
    public async Task<IActionResult> Eliminar(Guid animalId, Guid pesajeId)
    {
        try
        {
            return Ok(new { pesoActualAnimal = await _pesajeService.EliminarAsync(animalId, pesajeId) });
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
