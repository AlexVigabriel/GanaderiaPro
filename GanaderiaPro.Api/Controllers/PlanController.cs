using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-58: uso del plan del rancho frente a sus límites (solo el propietario).
[ApiController]
[Route("api/plan")]
[Authorize]
[Modulo(Modulo.Configuracion)]
public class PlanController : ControllerBase
{
    private readonly IControlLimitesPlan _limitesPlan;

    public PlanController(IControlLimitesPlan limitesPlan)
    {
        _limitesPlan = limitesPlan;
    }

    [HttpGet("uso")]
    public async Task<ActionResult<UsoPlanResponse>> ObtenerUso() => Ok(await _limitesPlan.ObtenerUsoAsync());
}
