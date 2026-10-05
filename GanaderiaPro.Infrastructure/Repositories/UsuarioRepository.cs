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

    public Task<bool> ExisteEmailAsync(string email) =>
        _dbContext.Usuarios.AnyAsync(u => u.Email == email);

    public Task<Usuario?> ObtenerPorEmailAsync(string email) =>
        _dbContext.Usuarios.Include(u => u.Rancho).FirstOrDefaultAsync(u => u.Email == email);

    public Task<Usuario?> ObtenerPorIdAsync(Guid id) =>
        _dbContext.Usuarios.FirstOrDefaultAsync(u => u.Id == id);

    public void Agregar(Usuario usuario) => _dbContext.Usuarios.Add(usuario);
}
