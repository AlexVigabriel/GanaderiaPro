using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class VacunacionRepository : IVacunacionRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public VacunacionRepository(GanaderiaProDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    private IQueryable<Vacunacion> ConDatos() =>
        _dbContext.Vacunaciones
            .Include(v => v.Animal)
            .Include(v => v.Vacuna)
            .Include(v => v.Veterinario);

    public void Agregar(Vacunacion vacunacion) => _dbContext.Vacunaciones.Add(vacunacion);

    public void Eliminar(Vacunacion vacunacion) => _dbContext.Vacunaciones.Remove(vacunacion);

    public Task<Vacunacion?> ObtenerPorIdAsync(Guid ranchoId, Guid id) =>
        ConDatos().FirstOrDefaultAsync(v => v.Id == id && v.Animal!.RanchoId == ranchoId);

    public async Task<IReadOnlyList<Vacunacion>> ListarPorAnimalAsync(Guid animalId) =>
        await ConDatos()
            .Where(v => v.AnimalId == animalId)
            .OrderByDescending(v => v.FechaAplicacion)
            .ThenByDescending(v => v.FechaRegistro)
            .ToListAsync();

    public async Task<IReadOnlyList<Vacunacion>> ListarRecientesAsync(Guid ranchoId, int cantidad) =>
        await ConDatos()
            .Where(v => v.Animal!.RanchoId == ranchoId)
            .OrderByDescending(v => v.FechaAplicacion)
            .ThenByDescending(v => v.FechaRegistro)
            .Take(cantidad)
            .ToListAsync();

    public async Task<IReadOnlyList<Vacuna>> ListarVacunasAsync() =>
        await _dbContext.Vacunas.OrderBy(v => v.Nombre).ToListAsync();

    public Task<Vacuna?> ObtenerVacunaAsync(Guid id) => _dbContext.Vacunas.FirstOrDefaultAsync(v => v.Id == id);
}
