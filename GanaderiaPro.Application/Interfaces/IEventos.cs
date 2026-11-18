using GanaderiaPro.Domain.Eventos;

namespace GanaderiaPro.Application.Interfaces;

// HU-40 (patrón Observer): el publicador avisa a todos los observadores.
public interface IPublicadorEventos
{
    Task PublicarAsync(IEventoRancho evento);
}

public interface IObservadorEventos
{
    Task ManejarAsync(IEventoRancho evento);
}

// Revisa los hechos que dependen del paso de los días (vacunas y partos).
public interface IRevisorAlertas
{
    Task RevisarAsync(Guid ranchoId);
}
