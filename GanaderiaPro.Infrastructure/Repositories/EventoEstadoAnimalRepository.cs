using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Repositories;

public class EventoEstadoAnimalRepository : IEventoEstadoAnimalRepository
{
    private readonly GanaderiaProDbContext _dbContext;

    public EventoEstadoAnimalRepository(GanaderiaProDbContext dbContext) => _dbContext = dbContext;

    public void Agregar(EventoEstadoAnimal evento) => _dbContext.EventosEstadoAnimal.Add(evento);

    public async Task<IReadOnlyList<EventoEstadoAnimal>> ListarPorAnimalAsync(Guid animalId) =>
        await _dbContext.EventosEstadoAnimal
            .Include(e => e.Usuario)
            .Where(e => e.AnimalId == animalId)
            .OrderByDescending(e => e.FechaEvento)
            .ThenByDescending(e => e.FechaRegistro)
            .ToListAsync();
}
