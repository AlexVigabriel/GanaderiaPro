using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-22: historial sanitario y de peso del animal. Es parte de la ficha, así
// que lo ve cualquier rol con lectura sobre Ganado.
[ApiController]
[Route("api/animales/{animalId:guid}/historial")]
[Authorize]
[Modulo(Modulo.Ganado)]
public class HistorialController : ControllerBase
{
    private readonly IHistorialAnimalService _historialService;

    public HistorialController(IHistorialAnimalService historialService)
    {
        _historialService = historialService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<EventoHistorialResponse>>> Listar(Guid animalId)
    {
        try
        {
            return Ok(await _historialService.ListarAsync(animalId));
        }
        catch (RecursoNoEncontradoException ex)
        {
            return NotFound(new { mensaje = ex.Message });
        }
    }
}
