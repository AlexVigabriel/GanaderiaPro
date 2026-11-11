using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class PrenezConfiguration : IEntityTypeConfiguration<Prenez>
{
    public void Configure(EntityTypeBuilder<Prenez> builder)
    {
        builder.ToTable("Preneces");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.Observacion)
            .HasMaxLength(500);

        builder.HasIndex(p => new { p.AnimalId, p.FechaServicio });

        // Para listar rápido las próximas a parir.
        builder.HasIndex(p => p.FechaProbableParto);

        builder.HasOne(p => p.Animal)
            .WithMany()
            .HasForeignKey(p => p.AnimalId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
