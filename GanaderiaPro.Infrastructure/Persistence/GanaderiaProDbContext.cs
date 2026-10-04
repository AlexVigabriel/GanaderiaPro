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
    public DbSet<Animal> Animales => Set<Animal>();
    public DbSet<Pesaje> Pesajes => Set<Pesaje>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(GanaderiaProDbContext).Assembly);
    }
}
