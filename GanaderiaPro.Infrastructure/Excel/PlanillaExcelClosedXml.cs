using System.Globalization;
using ClosedXML.Excel;
using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Infrastructure.Excel;

// HU-43 y HU-44: planilla de ganado con ClosedXML (licencia MIT).
public class PlanillaExcelClosedXml : IPlanillaExcel
{
    private static readonly string[] FormatosFecha = ["dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "yyyy-MM-dd"];

    public byte[] GenerarPlantilla()
    {
        using var libro = new XLWorkbook();
        var hoja = CrearHojaDatos(libro);

        // Fila de ejemplo: se ignora al importar.
        EscribirFila(hoja, 2, PlanillaGanado.AreteEjemplo, "H", "Nelore", new DateTime(2023, 5, 14), "Lucera", null, "Blanco", 380m, 32m,
            "Fila de ejemplo: borrala o reemplazala por tus animales.");
        hoja.Row(2).Style.Font.Italic = true;
        hoja.Row(2).Style.Font.FontColor = XLColor.Gray;

        var instrucciones = libro.Worksheets.Add(PlanillaGanado.HojaInstrucciones);
        instrucciones.Cell(1, 1).Value = "Columna";
        instrucciones.Cell(1, 2).Value = "Obligatoria";
        instrucciones.Cell(1, 3).Value = "Valores permitidos";
        instrucciones.Row(1).Style.Font.Bold = true;
        var fila = 2;
        foreach (var (columna, obligatoria, valores) in PlanillaGanado.Instrucciones)
        {
            instrucciones.Cell(fila, 1).Value = columna;
            instrucciones.Cell(fila, 2).Value = obligatoria ? "Sí" : "No";
            instrucciones.Cell(fila, 3).Value = valores;
            fila++;
        }

        fila++;
        instrucciones.Cell(fila, 1).Value =
            $"Completá la hoja «{PlanillaGanado.HojaDatos}» desde la fila 2, sin cambiar los encabezados. " +
            $"Hasta {PlanillaGanado.MaximoFilasImportacion} animales por archivo.";
        instrucciones.Column(1).Width = 24;
        instrucciones.Column(2).Width = 12;
        instrucciones.Column(3).Width = 60;

        return Guardar(libro);
    }

    public byte[] Exportar(IReadOnlyList<AnimalResponse> animales)
    {
        using var libro = new XLWorkbook();
        var hoja = CrearHojaDatos(libro);

        var fila = 2;
        foreach (var a in animales)
        {
            DateTime? nacimiento = a.FechaNacimiento?.ToDateTime(TimeOnly.MinValue);
            EscribirFila(hoja, fila++, a.Arete, a.Sexo == SexoAnimal.Hembra ? "H" : "M", a.Raza, nacimiento, a.Nombre,
                a.Sexo == SexoAnimal.Macho ? (a.Castrado ? "Sí" : "No") : null, a.Color, a.Peso, a.PesoNacimiento, a.Observaciones);
        }

        return Guardar(libro);
    }

    public LecturaPlanilla Leer(Stream archivo)
    {
        XLWorkbook libro;
        try
        {
            // ClosedXML necesita poder recorrer el archivo: se copia a memoria.
            var memoria = new MemoryStream();
            archivo.CopyTo(memoria);
            memoria.Position = 0;
            libro = new XLWorkbook(memoria);
        }
        catch (Exception)
        {
            return new LecturaPlanilla("El archivo no es un Excel (.xlsx) válido.", []);
        }

        using (libro)
        {
            if (!libro.TryGetWorksheet(PlanillaGanado.HojaDatos, out var hoja))
            {
                hoja = libro.Worksheets.First();
            }

            // Las columnas deben coincidir con la plantilla; si no, se rechaza completo.
            for (var c = 0; c < PlanillaGanado.Columnas.Count; c++)
            {
                var encabezado = hoja.Cell(1, c + 1).GetString().Trim();
                if (!string.Equals(encabezado, PlanillaGanado.Columnas[c], StringComparison.OrdinalIgnoreCase))
                {
                    return new LecturaPlanilla(
                        "Las columnas del archivo no coinciden con la plantilla. Descargá la plantilla y usá sus mismos encabezados.", []);
                }
            }

            var filas = new List<FilaPlanilla>();
            var ultima = hoja.LastRowUsed()?.RowNumber() ?? 1;
            for (var r = 2; r <= ultima; r++)
            {
                var celdas = Enumerable.Range(1, PlanillaGanado.Columnas.Count).Select(c => hoja.Cell(r, c)).ToArray();
                if (celdas.All(c => c.IsEmpty() || string.IsNullOrWhiteSpace(c.GetString())))
                {
                    continue;
                }

                var arete = celdas[0].GetString().Trim();
                if (string.Equals(arete, PlanillaGanado.AreteEjemplo, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                filas.Add(LeerFila(r, arete, celdas));
            }

            return new LecturaPlanilla(null, filas);
        }
    }

    private static FilaPlanilla LeerFila(int numero, string arete, IXLCell[] c)
    {
        var sexoTexto = Texto(c[1])?.ToUpperInvariant();
        SexoAnimal? sexo = sexoTexto switch
        {
            "M" or "MACHO" => SexoAnimal.Macho,
            "H" or "HEMBRA" => SexoAnimal.Hembra,
            _ => null,
        };
        if (sexo is null)
        {
            return new FilaPlanilla(numero, arete, null, "Sexo inválido: usá M o H.");
        }

        if (!LeerFecha(c[3], out var nacimiento))
        {
            return new FilaPlanilla(numero, arete, null, "Fecha de nacimiento inválida: usá dd/mm/aaaa.");
        }

        var castradoTexto = Texto(c[5])?.ToLowerInvariant();
        bool? castrado = castradoTexto switch
        {
            null or "no" => false,
            "si" or "sí" => true,
            _ => null,
        };
        if (castrado is null)
        {
            return new FilaPlanilla(numero, arete, null, "Castrado inválido: usá Sí o No.");
        }

        if (!LeerNumero(c[7], out var peso))
        {
            return new FilaPlanilla(numero, arete, null, "Peso inválido: tiene que ser un número.");
        }

        if (!LeerNumero(c[8], out var pesoNacimiento))
        {
            return new FilaPlanilla(numero, arete, null, "Peso al nacer inválido: tiene que ser un número.");
        }

        // El resto de las reglas (arete, raza, fechas futuras, pesos) las valida
        // la carga múltiple, igual que al registrar a mano.
        var datos = new RegistrarAnimalRequest(
            arete,
            sexo.Value,
            Texto(c[2]) ?? string.Empty,
            peso,
            Nombre: Texto(c[4]),
            FechaNacimiento: nacimiento,
            PesoNacimiento: pesoNacimiento,
            Color: Texto(c[6]),
            Observaciones: Texto(c[9]),
            Castrado: castrado.Value);
        return new FilaPlanilla(numero, arete, datos, null);
    }

    private static string? Texto(IXLCell celda)
    {
        var texto = celda.GetString().Trim();
        return texto.Length == 0 ? null : texto;
    }

    // Vacía → null (la carga múltiple avisa si es obligatoria).
    private static bool LeerFecha(IXLCell celda, out DateOnly? fecha)
    {
        fecha = null;
        if (celda.IsEmpty())
        {
            return true;
        }

        if (celda.DataType == XLDataType.DateTime)
        {
            fecha = DateOnly.FromDateTime(celda.GetDateTime());
            return true;
        }

        var texto = celda.GetString().Trim();
        if (DateOnly.TryParseExact(texto, FormatosFecha, CultureInfo.InvariantCulture, DateTimeStyles.None, out var leida))
        {
            fecha = leida;
            return true;
        }

        return false;
    }

    private static bool LeerNumero(IXLCell celda, out decimal? numero)
    {
        numero = null;
        if (celda.IsEmpty())
        {
            return true;
        }

        if (celda.DataType == XLDataType.Number)
        {
            numero = (decimal)celda.GetDouble();
            return true;
        }

        // Acepta coma o punto decimal.
        var texto = celda.GetString().Trim().Replace(',', '.');
        if (decimal.TryParse(texto, NumberStyles.Number, CultureInfo.InvariantCulture, out var leido))
        {
            numero = leido;
            return true;
        }

        return false;
    }

    private static IXLWorksheet CrearHojaDatos(XLWorkbook libro)
    {
        var hoja = libro.Worksheets.Add(PlanillaGanado.HojaDatos);
        for (var c = 0; c < PlanillaGanado.Columnas.Count; c++)
        {
            hoja.Cell(1, c + 1).Value = PlanillaGanado.Columnas[c];
            hoja.Column(c + 1).Width = c == PlanillaGanado.Columnas.Count - 1 ? 40 : 18;
        }

        var encabezado = hoja.Row(1);
        encabezado.Style.Font.Bold = true;
        encabezado.Style.Fill.BackgroundColor = XLColor.FromHtml("#E8F0E3");
        hoja.SheetView.FreezeRows(1);
        // Fecha de nacimiento en formato local.
        hoja.Column(4).Style.DateFormat.Format = "dd/mm/yyyy";
        return hoja;
    }

    private static void EscribirFila(IXLWorksheet hoja, int fila, string arete, string sexo, string raza, DateTime? nacimiento,
        string? nombre, string? castrado, string? color, decimal? peso, decimal? pesoNacimiento, string? observaciones)
    {
        hoja.Cell(fila, 1).Value = arete;
        hoja.Cell(fila, 2).Value = sexo;
        hoja.Cell(fila, 3).Value = raza;
        if (nacimiento is { } n) hoja.Cell(fila, 4).Value = n;
        if (nombre is not null) hoja.Cell(fila, 5).Value = nombre;
        if (castrado is not null) hoja.Cell(fila, 6).Value = castrado;
        if (color is not null) hoja.Cell(fila, 7).Value = color;
        if (peso is { } p) hoja.Cell(fila, 8).Value = (double)p;
        if (pesoNacimiento is { } pn) hoja.Cell(fila, 9).Value = (double)pn;
        if (observaciones is not null) hoja.Cell(fila, 10).Value = observaciones;
    }

    private static byte[] Guardar(XLWorkbook libro)
    {
        using var memoria = new MemoryStream();
        libro.SaveAs(memoria);
        return memoria.ToArray();
    }
}
