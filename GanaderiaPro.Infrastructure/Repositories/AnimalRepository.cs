using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class AnimalRepository : IAnimalRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public AnimalRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public Task<bool> ExisteAreteAsync(Guid ranchoId, string arete, Guid? excluirId = null) =>
        _dbContext.Animales.AnyAsync(
            a => a.RanchoId == ranchoId && a.Arete == arete && (excluirId == null || a.Id != excluirId));

    public Task<Animal?> ObtenerPorIdAsync(Guid ranchoId, Guid id) =>
        _dbContext.Animales.FirstOrDefaultAsync(a => a.RanchoId == ranchoId && a.Id == id);

    public void Agregar(Animal animal) => _dbContext.Animales.Add(animal);

    public void Eliminar(Animal animal) => _dbContext.Animales.Remove(animal);

    public async Task<IReadOnlyList<Animal>> BuscarAsync(Guid ranchoId, string? busqueda, EstadoAnimal estado, SexoAnimal? sexo, string? raza)
    {
        var query = _dbContext.Animales
            .Where(a => a.RanchoId == ranchoId && a.Estado == estado);

        if (!string.IsNullOrWhiteSpace(busqueda))
        {
            query = query.Where(a => a.Arete.Contains(busqueda));
        }

        if (sexo is not null)
        {
            query = query.Where(a => a.Sexo == sexo);
        }

        if (!string.IsNullOrWhiteSpace(raza))
        {
            query = query.Where(a => a.Raza == raza);
        }

        return await query
            .OrderByDescending(a => a.FechaRegistro)
            .ToListAsync();
    }
}
