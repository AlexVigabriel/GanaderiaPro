using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-12: indicadores generales del rancho. Todos los roles lo ven (lectura).
[ApiController]
[Route("api/tablero")]
[Authorize]
[Modulo(Modulo.Tablero)]
public class TableroController : ControllerBase
{
    private readonly ITableroService _tableroService;

    public TableroController(ITableroService tableroService)
    {
        _tableroService = tableroService;
    }

    [HttpGet("resumen")]
    public async Task<ActionResult<TableroResumenResponse>> ObtenerResumen() =>
        Ok(await _tableroService.ObtenerResumenAsync());
}
