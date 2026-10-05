using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class UsuarioRepository : IUsuarioRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public UsuarioRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    // RN-02: sin distinguir mayúsculas (el servicio ya manda el correo normalizado).
    public Task<bool> ExisteEmailAsync(string email) =>
        _dbContext.Usuarios.AnyAsync(u => u.Email.ToLower() == email.ToLower());

    public Task<Usuario?> ObtenerPorEmailAsync(string email) =>
        _dbContext.Usuarios.Include(u => u.Rancho).FirstOrDefaultAsync(u => u.Email.ToLower() == email.ToLower());

    public Task<Usuario?> ObtenerDelRanchoAsync(Guid ranchoId, Guid id) =>
        _dbContext.Usuarios.FirstOrDefaultAsync(u => u.RanchoId == ranchoId && u.Id == id);

    // Los Inactivos no cuentan: ya no usan el sistema.
    public Task<int> ContarQueOcupanLugarAsync(Guid ranchoId, IReadOnlyCollection<RolUsuario> roles)
    {
        var lista = roles.ToArray();
        return _dbContext.Usuarios.CountAsync(u =>
            u.RanchoId == ranchoId && lista.Contains(u.Rol) && u.Estado != EstadoUsuario.Inactivo);
    }

    public async Task<IReadOnlyList<Usuario>> ListarColaboradoresAsync(Guid ranchoId)
    {
        // Como arreglo, para que EF lo traduzca a "Rol IN (...)".
        var roles = Usuario.RolesDeColaborador.ToArray();
        return await _dbContext.Usuarios
            .Where(u => u.RanchoId == ranchoId && roles.Contains(u.Rol))
            .OrderBy(u => u.Nombre)
            .ToListAsync();
    }

    public Task<Usuario?> ObtenerPorIdAsync(Guid id) =>
        _dbContext.Usuarios.FirstOrDefaultAsync(u => u.Id == id);

    public void Agregar(Usuario usuario) => _dbContext.Usuarios.Add(usuario);
}
