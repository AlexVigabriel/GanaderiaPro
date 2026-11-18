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
    // número. Se descarta la que sigue a «corral» (es el nombre del corral).
    public IEnumerable<string> PosiblesAretes()
    {
        var tokens = Original.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries)
            .Select(t => t.Trim('¿', '?', '¡', '!', '.', ',', ';', ':', '«', '»', '"', '\'', '(', ')'))
            .ToList();
        for (var i = 0; i < tokens.Count; i++)
        {
            var anterior = i > 0 ? Normalizar(tokens[i - 1]) : string.Empty;
            if (tokens[i].Any(char.IsDigit) && anterior != "corral")
            {
                yield return tokens[i];
            }
        }
    }

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
