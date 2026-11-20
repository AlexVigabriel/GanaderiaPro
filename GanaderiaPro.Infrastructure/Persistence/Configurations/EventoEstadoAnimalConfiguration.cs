using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class EventoEstadoAnimalConfiguration : IEntityTypeConfiguration<EventoEstadoAnimal>
{
    public void Configure(EntityTypeBuilder<EventoEstadoAnimal> builder)
    {
        builder.ToTable("EventosEstadoAnimal");
        builder.HasKey(e => e.Id);
        builder.Property(e => e.EstadoAnterior).HasConversion<string>().HasMaxLength(20);
        builder.Property(e => e.EstadoNuevo).HasConversion<string>().HasMaxLength(20);
        builder.Property(e => e.Observacion).HasMaxLength(500);
        builder.HasIndex(e => new { e.AnimalId, e.FechaEvento, e.FechaRegistro });
        builder.HasOne(e => e.Animal).WithMany().HasForeignKey(e => e.AnimalId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(e => e.Usuario).WithMany().HasForeignKey(e => e.UsuarioId).OnDelete(DeleteBehavior.Restrict);
    }
}
