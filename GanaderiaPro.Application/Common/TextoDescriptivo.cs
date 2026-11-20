using System.Text.RegularExpressions;

namespace GanaderiaPro.Application.Common;

// RC-07 (correcciones del Sprint 3): una observación tiene que describir algo.
// «40» o «60» solos no dicen nada; «Peso registrado: 40 kg» sí. La regla: al
// menos una palabra de tres letras o más. Vacío sigue siendo válido (opcional).
public static partial class TextoDescriptivo
{
    public const string Mensaje = "debe describir algo, no solo un número.";

    public static bool EsDescriptivo(string? texto) =>
        string.IsNullOrWhiteSpace(texto) || PalabraDeTresLetras().IsMatch(texto);

    // Devuelve el problema o null. «campo» va al principio del mensaje, por
    // ejemplo «La observación» o «Las observaciones».
    public static string? Validar(string? texto, int maximo, string campo = "La observación")
    {
        var limpio = texto?.Trim() ?? string.Empty;
        if (limpio.Length > maximo)
        {
            return $"{campo} puede tener hasta {maximo} caracteres.";
        }

        if (!EsDescriptivo(limpio))
        {
            return campo.StartsWith("Las ", StringComparison.Ordinal)
                ? $"{campo} deben describir algo, no solo un número."
                : $"{campo} {Mensaje}";
        }

        return null;
    }

    [GeneratedRegex(@"\p{L}{3,}")]
    private static partial Regex PalabraDeTresLetras();
}
