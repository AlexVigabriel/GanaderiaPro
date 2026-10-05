using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Planes;

namespace GanaderiaPro.Application.DTOs;

// HU-58: uso de un recurso frente al límite del plan. Limite y Porcentaje
// son null cuando el plan no tiene límite.
public record UsoRecurso(RecursoPlan Recurso, int Usados, int? Limite, int? Porcentaje, bool CercaDelLimite, bool Lleno);

public record UsoPlanResponse(PlanSuscripcion Plan, string NombrePlan, string? PlanSiguiente, IReadOnlyList<UsoRecurso> Recursos);
