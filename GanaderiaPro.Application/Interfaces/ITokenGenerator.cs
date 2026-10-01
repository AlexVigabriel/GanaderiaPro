using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface ITokenGenerator
{
    string GenerarToken(Usuario usuario);
}
