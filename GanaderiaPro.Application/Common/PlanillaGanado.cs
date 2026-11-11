namespace GanaderiaPro.Application.Common;

// HU-43 y HU-44: formato de la planilla de ganado. La plantilla, la
// exportación y la importación usan estas mismas columnas, en este orden,
// así un archivo exportado se puede volver a importar.
public static class PlanillaGanado
{
    public const string HojaDatos = "Ganado";
    public const string HojaInstrucciones = "Instrucciones";
    public const int MaximoFilasImportacion = 1000;

    // La fila de ejemplo de la plantilla se ignora al importar.
    public const string AreteEjemplo = "EJEMPLO-001";

    public static readonly IReadOnlyList<string> Columnas =
    [
        "Arete",
        "Sexo",
        "Raza",
        "Fecha de nacimiento",
        "Nombre",
        "Castrado",
        "Color",
        "Peso (kg)",
        "Peso al nacer (kg)",
        "Observaciones",
    ];

    // Columna, si es obligatoria y valores permitidos (hoja de instrucciones).
    public static readonly IReadOnlyList<(string Columna, bool Obligatoria, string Valores)> Instrucciones =
    [
        ("Arete", true, "Único en el rancho. Letras, números y guiones (hasta 50)."),
        ("Sexo", true, "M (macho) o H (hembra)."),
        ("Raza", true, "Texto. Ej.: Nelore, Brahman, Criollo."),
        ("Fecha de nacimiento", true, "dd/mm/aaaa. No puede ser futura."),
        ("Nombre", false, "Texto."),
        ("Castrado", false, "Sí o No (solo machos). Vacío = No."),
        ("Color", false, "Texto."),
        ("Peso (kg)", false, "Número mayor que 0 y hasta 1500."),
        ("Peso al nacer (kg)", false, "Número entre 10 y 80."),
        ("Observaciones", false, "Texto."),
    ];
}
