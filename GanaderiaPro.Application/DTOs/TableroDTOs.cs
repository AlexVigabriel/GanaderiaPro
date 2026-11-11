namespace GanaderiaPro.Application.DTOs;

// HU-12: indicadores generales del rancho. Todos cuentan solo animales
// Activos (RN-04), salvo Fallecidos, que cuenta las bajas del año en curso.
public record TableroResumenResponse(
    int AnimalesActivos,
    int MachosActivos,
    int HembrasActivas,
    int Vacunados,
    int VacunacionesPendientes,
    int ProximasAParir,
    int FallecidosDelAnio,
    int CorralesActivos);
