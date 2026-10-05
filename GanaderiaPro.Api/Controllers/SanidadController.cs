using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-27: indicadores y vacunaciones pendientes del rancho.
[ApiController]
[Route("api")]
[Authorize]
public class SanidadController : ControllerBase
{
    private readonly ISanidadService _sanidadService;

    public SanidadController(ISanidadService sanidadService)
    {
        _sanidadService = sanidadService;
    }

    [HttpGet("sanidad/resumen")]
    public async Task<ActionResult<SanidadResumenResponse>> ObtenerResumen() =>
        Ok(await _sanidadService.ObtenerResumenAsync());

    [HttpGet("vacunaciones/pendientes")]
    public async Task<ActionResult<IReadOnlyList<PendienteResponse>>> ListarPendientes() =>
        Ok(await _sanidadService.ListarPendientesAsync());
}
