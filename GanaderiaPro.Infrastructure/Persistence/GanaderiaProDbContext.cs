using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace GanaderiaPro.Infrastructure.Persistence;

public class GanaderiaProDbContext : DbContext
{
    public GanaderiaProDbContext(DbContextOptions<GanaderiaProDbContext> options) : base(options)
    {
    }

    public DbSet<Rancho> Ranchos => Set<Rancho>();
    public DbSet<Usuario> Usuarios => Set<Usuario>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(GanaderiaProDbContext).Assembly);
    }
}
