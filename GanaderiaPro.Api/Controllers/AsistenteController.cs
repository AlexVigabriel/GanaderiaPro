using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-36.1 y HU-38: asistente de consultas. Es de lectura para todos los
// roles (fila «Dashboard y asistente» de la matriz); cada respuesta respeta
// además los permisos del módulo consultado.
[ApiController]
[Route("api/asistente")]
[Authorize]
[Modulo(Modulo.Tablero)]
public class AsistenteController : ControllerBase
{
    private readonly IAsistenteService _asistenteService;

    public AsistenteController(IAsistenteService asistenteService)
    {
        _asistenteService = asistenteService;
    }

    // Es una consulta: va por GET para que la permita el permiso de lectura.
    [HttpGet]
    public async Task<ActionResult<RespuestaAsistenteResponse>> Consultar([FromQuery] string? pregunta) =>
        Ok(await _asistenteService.ConsultarAsync(pregunta));

    [HttpGet("ejemplos")]
    public ActionResult<IReadOnlyList<string>> Ejemplos() => Ok(AsistenteService.Ejemplos);
}
