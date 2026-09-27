using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

[ApiController]
[Route("api/animales")]
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

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<AnimalResponse>>> Buscar(
        [FromQuery] string? busqueda,
        [FromQuery] EstadoAnimal? estado,
        [FromQuery] SexoAnimal? sexo,
        [FromQuery] string? raza)
    {
        var animales = await _animalService.BuscarAsync(busqueda, estado, sexo, raza);
        return Ok(animales);
    }
}
