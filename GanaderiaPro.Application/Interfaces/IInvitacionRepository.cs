using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IInvitacionRepository
{
    void Agregar(Invitacion invitacion);
    Task<Invitacion?> ObtenerPorHashAsync(string codigoHash);
    Task<IReadOnlyList<Invitacion>> ListarSinUsarAsync(Guid usuarioId);
    // Vencimiento de la última invitación sin usar de cada usuario del rancho.
    Task<IReadOnlyDictionary<Guid, DateTime>> VencimientosPendientesAsync(Guid ranchoId);
}
