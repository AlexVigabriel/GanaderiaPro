using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Persistence;

// TODO: borrar junto con StubCurrentUserContext cuando exista registro/login real.
public static class DevDataSeeder
{
    public static async Task SembrarRanchoDePruebaAsync(GanaderiaProDbContext dbContext)
    {
        var existe = await dbContext.Ranchos.AnyAsync(r => r.Id == StubCurrentUserContext.RanchoDePruebaId);
        if (existe)
        {
            return;
        }

        dbContext.Ranchos.Add(new Rancho
        {
            Id = StubCurrentUserContext.RanchoDePruebaId,
            Nombre = "Rancho de prueba (dev)",
            Plan = PlanSuscripcion.Basico,
            FechaRegistro = DateTime.UtcNow,
            FechaFinPruebaGratuita = DateTime.UtcNow.AddDays(10)
        });

        await dbContext.SaveChangesAsync();
    }
}
