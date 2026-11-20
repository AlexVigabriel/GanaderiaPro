namespace GanaderiaPro.Domain.Entities;

// RC-09: cómo terminó un tratamiento.
public enum ResultadoTratamiento
{
    Recuperado,
    SinMejoria,
    Derivado,
}

// RC-09: estado de un tratamiento respecto de hoy.
// SinResultado: pasó el último día y nadie cargó cómo terminó.
public enum EstadoTratamiento
{
    EnCurso,
    Finalizado,
    SinResultado,
}

// HU-57: tratamiento veterinario de un animal (distinto de una vacunación).
public class Tratamiento
{
    public Guid Id { get; set; }

    public Guid AnimalId { get; set; }
    public Animal? Animal { get; set; }

    // Veterinario responsable: el usuario que lo registró.
    public Guid VeterinarioId { get; set; }
    public Usuario? Veterinario { get; set; }

    // RC-08: el problema sanitario, por ejemplo «Neumonía».
    public string Diagnostico { get; set; } = string.Empty;
    public string Medicamento { get; set; } = string.Empty;
    public string Dosis { get; set; } = string.Empty;
    public DateOnly FechaInicio { get; set; }
    public int DuracionDias { get; set; }
    public string? Observacion { get; set; }
    public DateTime FechaRegistro { get; set; }

    // RC-09: finalización (puede ser antes del último día).
    public ResultadoTratamiento? Resultado { get; set; }
    public DateOnly? FechaFinalizacion { get; set; }
    public Guid? FinalizadoPorId { get; set; }
    public Usuario? FinalizadoPor { get; set; }

    // RC-09: un seguimiento por día mientras dura.
    public List<SeguimientoTratamiento> Seguimientos { get; set; } = [];

    // Último día del tratamiento (el de inicio cuenta como el primero).
    public DateOnly FechaFin => FechaInicio.AddDays(DuracionDias - 1);

    public bool Finalizado => Resultado is not null;

    public bool EnCursoAl(DateOnly hoy) => !Finalizado && hoy >= FechaInicio && hoy <= FechaFin;

    public EstadoTratamiento EstadoAl(DateOnly hoy) =>
        Finalizado ? EstadoTratamiento.Finalizado
        : hoy > FechaFin ? EstadoTratamiento.SinResultado
        : EstadoTratamiento.EnCurso;

    // «Día X de N»: el de inicio es el día 1; nunca pasa de N.
    public int DiaAl(DateOnly hoy) => Math.Clamp(hoy.DayNumber - FechaInicio.DayNumber + 1, 1, DuracionDias);
}

// RC-09: evolución del animal en un día del tratamiento.
public enum EvolucionTratamiento
{
    Mejora,
    SinCambios,
    Empeora,
}

public class SeguimientoTratamiento
{
    public Guid Id { get; set; }

    public Guid TratamientoId { get; set; }
    public Tratamiento? Tratamiento { get; set; }

    public DateOnly Fecha { get; set; }
    public EvolucionTratamiento Evolucion { get; set; }
    public string? Nota { get; set; }

    public Guid RegistradoPorId { get; set; }
    public Usuario? RegistradoPor { get; set; }
    public DateTime FechaRegistro { get; set; }
}
