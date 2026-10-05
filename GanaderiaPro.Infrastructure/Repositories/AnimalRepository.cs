using GanaderiaPro.Application.DTOs;
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

    // Sin distinguir mayúsculas, por si quedaron identificaciones cargadas en
    // minúsculas antes de que se normalizaran.
    public Task<bool> ExisteAreteAsync(Guid ranchoId, string arete, Guid? excluirId = null) =>
        _dbContext.Animales.AnyAsync(
            a => a.RanchoId == ranchoId && a.Arete.ToUpper() == arete.ToUpper() && (excluirId == null || a.Id != excluirId));

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
            var patron = $"%{busqueda.Trim()}%";
            query = query.Where(a =>
                EF.Functions.ILike(a.Arete, patron) ||
                (a.Nombre != null && EF.Functions.ILike(a.Nombre, patron)) ||
                EF.Functions.ILike(a.Raza, patron));
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

    public async Task<bool> TieneEventosAsync(Guid animalId) =>
        await _dbContext.Pesajes.AnyAsync(p => p.AnimalId == animalId) ||
        await _dbContext.Vacunaciones.AnyAsync(v => v.AnimalId == animalId);

    public async Task<IReadOnlyList<ConteoAnimales>> ContarPorEstadoYSexoAsync(Guid ranchoId) =>
        await _dbContext.Animales
            .Where(a => a.RanchoId == ranchoId)
            .GroupBy(a => new { a.Estado, a.Sexo })
            .Select(g => new ConteoAnimales(g.Key.Estado, g.Key.Sexo, g.Count()))
            .ToListAsync();
}
