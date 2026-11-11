using ClosedXML.Excel;
using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Excel;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-43.1, HU-43.2 y HU-44: planilla de ganado en Excel.
public class ExcelGanadoTests
{
    private readonly PlanillaExcelClosedXml _planilla = new();

    private static AnimalResponse Animal(string arete, SexoAnimal sexo, decimal? peso = null) => new(
        Guid.NewGuid(), arete, sexo, "Nelore", peso, EstadoAnimal.Activo, DateTime.UtcNow, "Lucera",
        new DateOnly(2023, 5, 14), 30m, "Blanco", null, false, null, null, null, null, null);

    // Excel en memoria con los encabezados de la plantilla y las filas dadas.
    private static MemoryStream Archivo(params object?[][] filas)
    {
        using var libro = new XLWorkbook();
        var hoja = libro.Worksheets.Add(PlanillaGanado.HojaDatos);
        for (var c = 0; c < PlanillaGanado.Columnas.Count; c++)
        {
            hoja.Cell(1, c + 1).Value = PlanillaGanado.Columnas[c];
        }

        for (var r = 0; r < filas.Length; r++)
        {
            for (var c = 0; c < filas[r].Length; c++)
            {
                hoja.Cell(r + 2, c + 1).Value = filas[r][c] switch
                {
                    null => Blank.Value,
                    DateTime d => d,
                    double n => n,
                    var v => v.ToString(),
                };
            }
        }

        var memoria = new MemoryStream();
        libro.SaveAs(memoria);
        memoria.Position = 0;
        return memoria;
    }

    [Fact]
    public void Plantilla_TieneEncabezadosEjemploEInstrucciones()
    {
        using var libro = new XLWorkbook(new MemoryStream(_planilla.GenerarPlantilla()));

        var hoja = libro.Worksheet(PlanillaGanado.HojaDatos);
        Assert.Equal(PlanillaGanado.Columnas, Enumerable.Range(1, PlanillaGanado.Columnas.Count).Select(c => hoja.Cell(1, c).GetString()));
        Assert.Equal(PlanillaGanado.AreteEjemplo, hoja.Cell(2, 1).GetString());
        Assert.Contains("M (macho) o H (hembra)", libro.Worksheet(PlanillaGanado.HojaInstrucciones).Cell(3, 3).GetString());
    }

    [Fact]
    public void Plantilla_AlImportarseSinCambios_NoTraeFilas()
    {
        // La fila de ejemplo se ignora.
        var lectura = _planilla.Leer(new MemoryStream(_planilla.GenerarPlantilla()));

        Assert.Null(lectura.ErrorArchivo);
        Assert.Empty(lectura.Filas);
    }

    [Fact]
    public void Exportar_YVolverALeer_ConservaLosDatos()
    {
        // HU-44: mismas columnas que la plantilla, así se puede reimportar.
        var bytes = _planilla.Exportar([Animal("AR-001", SexoAnimal.Hembra, 420.5m), Animal("AR-002", SexoAnimal.Macho)]);

        var lectura = _planilla.Leer(new MemoryStream(bytes));

        Assert.Null(lectura.ErrorArchivo);
        Assert.Equal(2, lectura.Filas.Count);
        var primera = lectura.Filas[0].Datos!;
        Assert.Equal("AR-001", primera.Arete);
        Assert.Equal(SexoAnimal.Hembra, primera.Sexo);
        Assert.Equal(new DateOnly(2023, 5, 14), primera.FechaNacimiento);
        Assert.Equal(420.5m, primera.Peso);
        Assert.Null(lectura.Filas[1].Datos!.Peso);
    }

    [Fact]
    public void Leer_ColumnasDistintas_RechazaElArchivoCompleto()
    {
        using var libro = new XLWorkbook();
        libro.Worksheets.Add("Hoja1").Cell(1, 1).Value = "Identificación";
        var memoria = new MemoryStream();
        libro.SaveAs(memoria);
        memoria.Position = 0;

        var lectura = _planilla.Leer(memoria);

        Assert.Contains("no coinciden con la plantilla", lectura.ErrorArchivo);
    }

    [Fact]
    public void Leer_ArchivoQueNoEsExcel_LoRechaza()
    {
        var lectura = _planilla.Leer(new MemoryStream("hola"u8.ToArray()));

        Assert.Equal("El archivo no es un Excel (.xlsx) válido.", lectura.ErrorArchivo);
    }

    [Fact]
    public void Leer_FilasConFormatoInvalido_TraenElMotivo()
    {
        var archivo = Archivo(
            ["AR-010", "H", "Nelore", "14/05/2023"],
            ["AR-011", "X", "Nelore", "14/05/2023"],
            ["AR-012", "M", "Nelore", "2023/99/99"],
            ["AR-013", "M", "Nelore", new DateTime(2022, 1, 2), null, "talvez"]);

        var filas = _planilla.Leer(archivo).Filas;

        Assert.NotNull(filas[0].Datos);
        Assert.Equal((3, "Sexo inválido: usá M o H."), (filas[1].Fila, filas[1].Error));
        Assert.Equal("Fecha de nacimiento inválida: usá dd/mm/aaaa.", filas[2].Error);
        Assert.Equal("Castrado inválido: usá Sí o No.", filas[3].Error);
    }

    [Fact]
    public async Task Importar_JuntaRechazosDelFormatoYDeLaCarga_ConElNumeroDeFilaDelExcel()
    {
        // HU-43.2: arete repetido (RN-01) lo rechaza la carga múltiple; el resto se importa.
        var animalService = new Mock<IAnimalService>();
        animalService
            .Setup(s => s.RegistrarLoteAsync(It.IsAny<IReadOnlyList<RegistrarAnimalRequest>>(), PlanillaGanado.MaximoFilasImportacion))
            .ReturnsAsync((IReadOnlyList<RegistrarAnimalRequest> filas, int _) => new RegistrarLoteResponse(
                [Animal(filas[0].Arete, SexoAnimal.Hembra)],
                [new FilaRechazada(2, filas[1].Arete, "Ya existe un animal con la identificación 'AR-001' en este rancho.")]));
        var servicio = new ExcelGanadoService(_planilla, animalService.Object);
        var archivo = Archivo(
            ["AR-020", "H", "Nelore", "14/05/2023"],
            ["AR-021", "X", "Nelore", "14/05/2023"],
            ["AR-001", "M", "Nelore", "14/05/2023"]);

        var resultado = await servicio.ImportarAsync(archivo);

        Assert.Equal(1, resultado.Importadas);
        Assert.Equal(2, resultado.Rechazadas);
        Assert.Equal(new[] { 3, 4 }, resultado.Detalle.Select(d => d.Fila));
    }

    [Fact]
    public async Task Importar_ArchivoInvalido_SeRechazaCompleto()
    {
        var servicio = new ExcelGanadoService(_planilla, new Mock<IAnimalService>().Object);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.ImportarAsync(new MemoryStream("x"u8.ToArray())));
    }
}
