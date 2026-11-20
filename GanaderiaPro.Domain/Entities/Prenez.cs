namespace GanaderiaPro.Domain.Entities;

// RC-10: resultado del diagnóstico de preñez (palpación o ecografía).
public enum DiagnosticoPrenez
{
    Confirmada,
    Vacia,
}

// RC-10: cómo está la preñez. Parto, Vacia y Aborto la cierran.
public enum EstadoPrenez
{
    Abierta,
    Parto,
    Vacia,
    Aborto,
}

// HU-56: servicio de una hembra y, cuando ocurre, su parto. RC-10: también el
// diagnóstico de preñez y el aborto. Mientras no se cierra, la preñez está abierta.
public class Prenez
{
    // RN-10: días de gestación de los bovinos.
    public const int DiasGestacion = 283;

    // RC-10: plazos biológicos contados desde el servicio.
    // La ecografía detecta la preñez desde los 28-30 días; la palpación, desde los 35-45.
    public const int DiasMinimosDiagnostico = 30;
    // Antes de los 42 días es muerte embrionaria; desde los 260, parto (prematuro).
    public const int DiasMinimosAborto = 42;
    public const int DiasMinimosParto = 260;
    // Espera antes de un nuevo servicio: involución uterina tras el parto y un
    // ciclo de celo (21 días) tras el aborto.
    public const int EsperaTrasParto = 40;
    public const int EsperaTrasAborto = 21;

    public Guid Id { get; set; }

    public Guid AnimalId { get; set; }
    public Animal? Animal { get; set; }

    public DateOnly FechaServicio { get; set; }
    // Se guarda para poder buscar rápido las próximas a parir (tablero y alertas).
    public DateOnly FechaProbableParto { get; set; }
    public DateOnly? FechaParto { get; set; }
    public string? Observacion { get; set; }
    public DateTime FechaRegistro { get; set; }

    // RC-10: diagnóstico de preñez y aborto.
    public DiagnosticoPrenez? Diagnostico { get; set; }
    public DateOnly? FechaDiagnostico { get; set; }
    public DateOnly? FechaAborto { get; set; }

    // HU-22: usuario que registró el servicio (vacío en los anteriores a esta versión).
    public Guid? RegistradoPorId { get; set; }
    public Usuario? RegistradoPor { get; set; }
    public Guid? PartoRegistradoPorId { get; set; }
    public Usuario? PartoRegistradoPor { get; set; }

    public EstadoPrenez Estado =>
        FechaParto is not null ? EstadoPrenez.Parto
        : FechaAborto is not null ? EstadoPrenez.Aborto
        : Diagnostico == DiagnosticoPrenez.Vacia ? EstadoPrenez.Vacia
        : EstadoPrenez.Abierta;

    public bool Abierta => Estado == EstadoPrenez.Abierta;

    // Fecha en que se cerró (parto, aborto o diagnóstico «Vacía»).
    public DateOnly? FechaCierre => Estado switch
    {
        EstadoPrenez.Parto => FechaParto,
        EstadoPrenez.Aborto => FechaAborto,
        EstadoPrenez.Vacia => FechaDiagnostico,
        _ => null,
    };

    public DateOnly DiagnosticoDesde => FechaServicio.AddDays(DiasMinimosDiagnostico);
    public DateOnly AbortoDesde => FechaServicio.AddDays(DiasMinimosAborto);
    // El último día en que todavía es aborto (el 260 ya es parto).
    public DateOnly AbortoHasta => FechaServicio.AddDays(DiasMinimosParto - 1);
    public DateOnly PartoDesde => FechaServicio.AddDays(DiasMinimosParto);

    // Desde qué fecha se acepta un nuevo servicio después de que se cerró esta preñez.
    public DateOnly? ServicioPosibleDesde => Estado switch
    {
        EstadoPrenez.Parto => FechaParto!.Value.AddDays(EsperaTrasParto),
        EstadoPrenez.Aborto => FechaAborto!.Value.AddDays(EsperaTrasAborto),
        EstadoPrenez.Vacia => FechaDiagnostico,
        _ => null,
    };

    public static DateOnly CalcularFechaProbableParto(DateOnly fechaServicio) => fechaServicio.AddDays(DiasGestacion);
}
