using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IUsuarioRepository
{
    Task<bool> ExisteEmailAsync(string email);
    Task<Usuario?> ObtenerPorEmailAsync(string email);
    void Agregar(Usuario usuario);
}
