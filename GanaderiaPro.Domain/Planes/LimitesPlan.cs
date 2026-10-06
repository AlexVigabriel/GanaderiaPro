using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Domain.Planes;

// HU-58: lo que limita cada plan (RN-11).
public enum RecursoPlan
{
    Animales,
    Colaboradores,
    Socios
}

// Patrón Strategy: cada plan es una estrategia con sus propios límites. Para
// agregar un plan o cambiar un número se toca solo su clase.
public interface ILimitesPlan
{
    PlanSuscripcion Plan { get; }
    string Nombre { get; }

    // null: sin límite.
    int? Limite(RecursoPlan recurso);

    // Plan al que conviene pasarse cuando se llega al límite (null si es el más alto).
    string? PlanSiguiente { get; }
}

public sealed class PlanBasico : ILimitesPlan
{
    public PlanSuscripcion Plan => PlanSuscripcion.Basico;
    public string Nombre => "Básico";
    public string? PlanSiguiente => "Intermedio";

    public int? Limite(RecursoPlan recurso) => recurso switch
    {
        RecursoPlan.Animales => 100,
        RecursoPlan.Colaboradores => 3,
        RecursoPlan.Socios => 2,
        _ => null,
    };
}

public sealed class PlanIntermedio : ILimitesPlan
{
    public PlanSuscripcion Plan => PlanSuscripcion.Intermedio;
    public string Nombre => "Intermedio";
    public string? PlanSiguiente => "Superior";

    public int? Limite(RecursoPlan recurso) => recurso switch
    {
        RecursoPlan.Animales => 200,
        RecursoPlan.Colaboradores => 5,
        RecursoPlan.Socios => 4,
        _ => null,
    };
}

// RN-11: "capacidades ampliadas" sin números definidos por el Product Owner:
// queda sin límite hasta que se decidan.
public sealed class PlanSuperior : ILimitesPlan
{
    public PlanSuscripcion Plan => PlanSuscripcion.Superior;
    public string Nombre => "Superior";
    public string? PlanSiguiente => null;

    public int? Limite(RecursoPlan recurso) => null;
}

public static class EstrategiasPlan
{
    public static ILimitesPlan Para(PlanSuscripcion plan) => plan switch
    {
        PlanSuscripcion.Basico => new PlanBasico(),
        PlanSuscripcion.Intermedio => new PlanIntermedio(),
        _ => new PlanSuperior(),
    };
}
