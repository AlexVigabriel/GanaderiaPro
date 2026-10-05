using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class VacunacionConfiguration : IEntityTypeConfiguration<Vacunacion>
{
    public void Configure(EntityTypeBuilder<Vacunacion> builder)
    {
        builder.ToTable("Vacunaciones");
        builder.HasKey(v => v.Id);

        builder.Property(v => v.Dosis).IsRequired().HasMaxLength(50);
        builder.Property(v => v.Observacion).HasMaxLength(500);

        builder.HasIndex(v => new { v.AnimalId, v.FechaAplicacion });
        builder.HasIndex(v => v.FechaProximaDosis);

        builder.HasOne(v => v.Animal)
            .WithMany()
            .HasForeignKey(v => v.AnimalId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(v => v.Vacuna)
            .WithMany()
            .HasForeignKey(v => v.VacunaId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(v => v.Veterinario)
            .WithMany()
            .HasForeignKey(v => v.VeterinarioId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
