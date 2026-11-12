using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-43.1, HU-43.2 y HU-44: plantilla, importación y exportación de ganado.
// La importación reutiliza la carga múltiple (HU-66): mismas validaciones,
// arete único (RN-01) y límite del plan (RN-11).
public class ExcelGanadoService : IExcelGanadoService
{
    private readonly IPlanillaExcel _planilla;
    private readonly IAnimalService _animalService;

    public ExcelGanadoService(IPlanillaExcel planilla, IAnimalService animalService)
    {
        _planilla = planilla;
        _animalService = animalService;
    }

    public byte[] DescargarPlantilla() => _planilla.GenerarPlantilla();

    // Respeta los filtros aplicados en el listado.
    public async Task<byte[]> ExportarAsync(
        string? busqueda, EstadoAnimal? estado, SexoAnimal? sexo, string? raza, CategoriaAnimal? categoria) =>
        _planilla.Exportar(await _animalService.BuscarAsync(busqueda, estado, sexo, raza, categoria));

    public async Task<ImportacionResponse> ImportarAsync(Stream archivo)
    {
        var lectura = _planilla.Leer(archivo);
        if (lectura.ErrorArchivo is { } error)
        {
            throw new ReglaDeNegocioException(error);
        }

        if (lectura.Filas.Count == 0)
        {
            throw new ReglaDeNegocioException("El archivo no tiene animales para importar.");
        }

        if (lectura.Filas.Count > PlanillaGanado.MaximoFilasImportacion)
        {
            throw new ReglaDeNegocioException(
                $"El archivo tiene {lectura.Filas.Count} filas; se pueden importar hasta {PlanillaGanado.MaximoFilasImportacion} por vez.");
        }

        var rechazadas = lectura.Filas
            .Where(f => f.Datos is null)
            .Select(f => new FilaRechazada(f.Fila, f.Arete, f.Error ?? "Fila inválida."))
            .ToList();
        var validas = lectura.Filas.Where(f => f.Datos is not null).ToList();

        var importadas = 0;
        if (validas.Count > 0)
        {
            var resultado = await _animalService.RegistrarLoteAsync(
                validas.Select(f => f.Datos!).ToList(), PlanillaGanado.MaximoFilasImportacion);
            importadas = resultado.Registrados.Count;
            // La carga numera desde 1 dentro de lo enviado: se pasa al número de fila del Excel.
            rechazadas.AddRange(resultado.Rechazados.Select(r => r with { Fila = validas[r.Fila - 1].Fila }));
        }

        return new ImportacionResponse(importadas, rechazadas.Count, rechazadas.OrderBy(r => r.Fila).ToList());
    }
}
