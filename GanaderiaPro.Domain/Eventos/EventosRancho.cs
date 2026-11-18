using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Domain.Eventos;

// HU-40 (patrón Observer): hechos del rancho que pueden interesar a alguien.
// Quien los detecta los publica; los observadores deciden qué hacer con ellos
// (hoy, crear notificaciones; mañana podría ser enviar un correo).
public interface IEventoRancho
{
    Guid RanchoId { get; }
}

// RN-09: próxima dosis vencida o dentro de los próximos 7 días.
public sealed record VacunaPendienteDetectada(
    Guid RanchoId,
    Guid VacunacionId,
    Guid AnimalId,
    string Arete,
    string Vacuna,
    DateOnly FechaProximaDosis) : IEventoRancho;

// Se asignó el animal que completa la capacidad del corral.
public sealed record CorralLleno(Guid RanchoId, Guid CorralId, string Nombre, int Capacidad) : IEventoRancho;

// RN-10: parto probable dentro de los próximos 15 días.
public sealed record PartoProximo(
    Guid RanchoId,
    Guid PrenezId,
    Guid AnimalId,
    string Arete,
    DateOnly FechaProbableParto) : IEventoRancho;

// HU-38: el asistente reconoció la consulta pero el dato no está registrado.
// Clave identifica la consulta (por ejemplo, «peso:AR-002»): no se avisa dos
// veces lo mismo dentro de 24 horas.
public sealed record DatoFaltante(
    Guid RanchoId,
    string Dato,
    RolUsuario Responsable,
    string Clave) : IEventoRancho;
