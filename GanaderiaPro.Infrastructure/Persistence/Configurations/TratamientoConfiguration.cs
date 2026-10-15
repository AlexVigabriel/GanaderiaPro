using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class TratamientoConfiguration : IEntityTypeConfiguration<Tratamiento>
{
    public void Configure(EntityTypeBuilder<Tratamiento> builder)
    {
        builder.ToTable("Tratamientos");

        builder.HasKey(t => t.Id);

        builder.Property(t => t.Motivo).IsRequired().HasMaxLength(200);
        builder.Property(t => t.Medicamento).IsRequired().HasMaxLength(150);
        builder.Property(t => t.Dosis).IsRequired().HasMaxLength(100);
        builder.Property(t => t.Observacion).HasMaxLength(500);

        builder.HasIndex(t => new { t.AnimalId, t.FechaInicio });

        builder.HasOne(t => t.Animal)
            .WithMany()
            .HasForeignKey(t => t.AnimalId)
            .OnDelete(DeleteBehavior.Cascade);

        // El historial sanitario no se pierde si se borra un usuario.
        builder.HasOne(t => t.Veterinario)
            .WithMany()
            .HasForeignKey(t => t.VeterinarioId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
