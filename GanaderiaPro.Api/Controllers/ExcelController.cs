using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-43.1, HU-43.2 y HU-44: Excel de ganado. Importar y exportar son filas
// propias de la matriz de permisos (sección 5).
[ApiController]
[Route("api/animales/excel")]
[Authorize]
public class ExcelController : ControllerBase
{
    private const string TipoExcel = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    private const long TamanoMaximo = 5 * 1024 * 1024;

    private readonly IExcelGanadoService _excelService;

    public ExcelController(IExcelGanadoService excelService)
    {
        _excelService = excelService;
    }

    [HttpGet("plantilla")]
    [Modulo(Modulo.ImportarExcel)]
    public FileContentResult DescargarPlantilla() =>
        File(_excelService.DescargarPlantilla(), TipoExcel, "plantilla_ganado.xlsx");

    // Respeta los mismos filtros que el listado de ganado.
    [HttpGet("exportar")]
    [Modulo(Modulo.ExportarExcel)]
    public async Task<FileContentResult> Exportar(
        [FromQuery] string? busqueda,
        [FromQuery] EstadoAnimal? estado,
        [FromQuery] SexoAnimal? sexo,
        [FromQuery] string? raza,
        [FromQuery] CategoriaAnimal? categoria)
    {
        var bytes = await _excelService.ExportarAsync(busqueda, estado, sexo, raza, categoria);
        return File(bytes, TipoExcel, $"ganado_{FechaRancho.Hoy():yyyy-MM-dd}.xlsx");
    }

    [HttpPost("importar")]
    [Modulo(Modulo.ImportarExcel)]
    [RequestSizeLimit(TamanoMaximo)]
    public async Task<ActionResult<ImportacionResponse>> Importar(IFormFile? archivo)
    {
        if (archivo is null || archivo.Length == 0)
        {
            return BadRequest(new { mensaje = "Elegí un archivo .xlsx para importar." });
        }

        try
        {
            await using var contenido = archivo.OpenReadStream();
            return Ok(await _excelService.ImportarAsync(contenido));
        }
        catch (ReglaDeNegocioException ex)
        {
            return BadRequest(new { mensaje = ex.Message });
        }
    }
}
