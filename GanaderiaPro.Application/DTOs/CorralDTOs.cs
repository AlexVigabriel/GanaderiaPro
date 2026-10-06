namespace GanaderiaPro.Application.DTOs;

// HU-23: al crear el corral se pueden asignar animales (RN-07: sin pasar la capacidad).
public record CrearCorralRequest(string Nombre, int Capacidad, IReadOnlyList<Guid>? AnimalIds = null);

public record EditarCorralRequest(string Nombre, int Capacidad);

// Corral nuevo del animal; null lo deja sin corral.
public record AsignarCorralRequest(Guid? CorralId);

// HU-24: animales activos (sin bajas, RN-04) y porcentaje de ocupación.
public record CorralResponse(
    Guid Id,
    string Nombre,
    int Capacidad,
    bool Activo,
    int AnimalesActivos,
    int PorcentajeOcupacion);
