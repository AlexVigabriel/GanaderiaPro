namespace GanaderiaPro.Application.DTOs;

// HU-43.2: una fila leída del Excel. Si no se pudo interpretar (por ejemplo,
// sexo o fecha con formato inválido), Datos es null y Error dice por qué.
public record FilaPlanilla(int Fila, string Arete, RegistrarAnimalRequest? Datos, string? Error);

// ErrorArchivo: el archivo no se puede importar (no es Excel o sus columnas no
// coinciden con la plantilla): se rechaza completo.
public record LecturaPlanilla(string? ErrorArchivo, IReadOnlyList<FilaPlanilla> Filas);

// Resumen «N importadas, M rechazadas» con el motivo de cada fila rechazada
// (Fila = número de fila en el Excel).
public record ImportacionResponse(int Importadas, int Rechazadas, IReadOnlyList<FilaRechazada> Detalle);
