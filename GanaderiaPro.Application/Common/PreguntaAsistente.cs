using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace GanaderiaPro.Application.Common;

// HU-36.1: la pregunta del usuario lista para comparar: minúsculas, sin
// tildes (la ñ queda como n), sin signos y con un solo espacio entre palabras.
public sealed partial class PreguntaAsistente
{
    public PreguntaAsistente(string? original)
    {
        Original = (original ?? string.Empty).Trim();
        Texto = Normalizar(Original);
        Palabras = Texto.Split(' ', StringSplitOptions.RemoveEmptyEntries);
    }

    public string Original { get; }
    public string Texto { get; }
    public IReadOnlyList<string> Palabras { get; }

    public bool Contiene(params string[] fragmentos) => fragmentos.Any(f => Texto.Contains(f, StringComparison.Ordinal));

    // ¿Aparece el texto como palabra(s) completa(s)? «sur» no coincide con «surco».
    public bool ContienePalabras(string texto)
    {
        var buscado = Normalizar(texto);
        return buscado.Length > 0 && $" {Texto} ".Contains($" {buscado} ", StringComparison.Ordinal);
    }

    // Palabras del texto original que podrían ser un arete: tienen al menos un
    // número. Se descarta la que sigue a «corral» o a «corral número» (es el
    // nombre del corral).
    public IEnumerable<string> PosiblesAretes()
    {
        var tokens = Original.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries)
            .Select(t => t.Trim('¿', '?', '¡', '!', '.', ',', ';', ':', '«', '»', '"', '\'', '(', ')'))
            .ToList();
        for (var i = 0; i < tokens.Count; i++)
        {
            var anterior = i > 0 ? Normalizar(tokens[i - 1]) : string.Empty;
            var antesDeAnterior = i > 1 ? Normalizar(tokens[i - 2]) : string.Empty;
            var esNombreDeCorral = anterior == "corral" || (PalabrasNumero.Contains(anterior) && antesDeAnterior == "corral");
            if (tokens[i].Any(char.IsDigit) && !esNombreDeCorral)
            {
                yield return tokens[i];
            }
        }
    }

    // RC-06: lo que el usuario escribió después de «corral», listo para
    // comparar con el nombre del corral («corral número cuatro» → «4»).
    public IReadOnlyList<string> DespuesDeCorral()
    {
        var indice = Palabras.ToList().IndexOf("corral");
        return indice < 0 ? [] : ClaveCorral(string.Join(' ', Palabras.Skip(indice + 1)));
    }

    // RC-06: el nombre de un corral sin «corral» ni «número» al principio y
    // con los números escritos en palabras pasados a cifras. Así «Corral 4»,
    // «corral cuatro» y «Corral N° 4» quedan iguales: «4».
    public static IReadOnlyList<string> ClaveCorral(string? nombre)
    {
        var palabras = Normalizar(nombre).Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Select(p => NumerosEnPalabras.TryGetValue(p, out var cifra) ? cifra : p)
            .ToList();
        while (palabras.Count > 0 && (palabras[0] == "corral" || PalabrasNumero.Contains(palabras[0])))
        {
            palabras.RemoveAt(0);
        }

        return palabras;
    }

    // Distancia de edición (cantidad de letras agregadas, borradas o
    // cambiadas). Sirve para aceptar un error de tipeo en un nombre.
    public static int Distancia(string a, string b)
    {
        var anterior = Enumerable.Range(0, b.Length + 1).ToArray();
        for (var i = 1; i <= a.Length; i++)
        {
            var actual = new int[b.Length + 1];
            actual[0] = i;
            for (var j = 1; j <= b.Length; j++)
            {
                var costo = a[i - 1] == b[j - 1] ? 0 : 1;
                actual[j] = Math.Min(Math.Min(actual[j - 1] + 1, anterior[j] + 1), anterior[j - 1] + costo);
            }

            anterior = actual;
        }

        return anterior[b.Length];
    }

    private static readonly HashSet<string> PalabrasNumero = ["numero", "nro", "n", "no", "num"];

    // Del cero al veinte, que alcanza para los nombres de corral habituales.
    private static readonly Dictionary<string, string> NumerosEnPalabras = new()
    {
        ["cero"] = "0", ["uno"] = "1", ["dos"] = "2", ["tres"] = "3", ["cuatro"] = "4", ["cinco"] = "5",
        ["seis"] = "6", ["siete"] = "7", ["ocho"] = "8", ["nueve"] = "9", ["diez"] = "10", ["once"] = "11",
        ["doce"] = "12", ["trece"] = "13", ["catorce"] = "14", ["quince"] = "15", ["dieciseis"] = "16",
        ["diecisiete"] = "17", ["dieciocho"] = "18", ["diecinueve"] = "19", ["veinte"] = "20",
    };

    public static string Normalizar(string? texto)
    {
        if (string.IsNullOrWhiteSpace(texto))
        {
            return string.Empty;
        }

        var descompuesto = texto.ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var sinTildes = new StringBuilder(descompuesto.Length);
        foreach (var c in descompuesto)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
            {
                sinTildes.Append(c);
            }
        }

        var limpio = Signos().Replace(sinTildes.ToString(), " ");
        return Espacios().Replace(limpio, " ").Trim();
    }

    [GeneratedRegex(@"[^a-z0-9\- ]")]
    private static partial Regex Signos();

    [GeneratedRegex(@"\s+")]
    private static partial Regex Espacios();
}
