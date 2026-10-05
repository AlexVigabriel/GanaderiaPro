using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IUsuarioRepository
{
    Task<bool> ExisteEmailAsync(string email);
    Task<Usuario?> ObtenerPorEmailAsync(string email);
    Task<Usuario?> ObtenerPorIdAsync(Guid id);
    Task<Usuario?> ObtenerDelRanchoAsync(Guid ranchoId, Guid id);
    Task<IReadOnlyList<Usuario>> ListarColaboradoresAsync(Guid ranchoId);

    // HU-58: usuarios que ocupan lugar en el plan (Pendientes y Activos).
    Task<int> ContarQueOcupanLugarAsync(Guid ranchoId, IReadOnlyCollection<RolUsuario> roles);
    void Agregar(Usuario usuario);
}
