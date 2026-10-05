namespace GanaderiaPro.Application.Interfaces;

public interface ICurrentUserContext
{
    Guid RanchoId { get; }
    Guid UsuarioId { get; }
}
