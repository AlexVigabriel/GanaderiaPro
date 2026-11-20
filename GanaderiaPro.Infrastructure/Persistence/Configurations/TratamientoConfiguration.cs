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

        builder.Property(t => t.Diagnostico).IsRequired().HasMaxLength(100);
        builder.Property(t => t.Medicamento).IsRequired().HasMaxLength(150);
        builder.Property(t => t.Dosis).IsRequired().HasMaxLength(100);
        builder.Property(t => t.Observacion).HasMaxLength(300);
        builder.Property(t => t.Resultado).HasConversion<string>().HasMaxLength(20);

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

        builder.HasOne(t => t.FinalizadoPor)
            .WithMany()
            .HasForeignKey(t => t.FinalizadoPorId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(t => t.Seguimientos)
            .WithOne(s => s.Tratamiento)
            .HasForeignKey(s => s.TratamientoId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

// RC-09
public class SeguimientoTratamientoConfiguration : IEntityTypeConfiguration<SeguimientoTratamiento>
{
    public void Configure(EntityTypeBuilder<SeguimientoTratamiento> builder)
    {
        builder.ToTable("SeguimientosTratamiento");

        builder.HasKey(s => s.Id);

        builder.Property(s => s.Evolucion).HasConversion<string>().HasMaxLength(20);
        builder.Property(s => s.Nota).HasMaxLength(300);

        // Un solo seguimiento por día y tratamiento.
        builder.HasIndex(s => new { s.TratamientoId, s.Fecha }).IsUnique();

        builder.HasOne(s => s.RegistradoPor)
            .WithMany()
            .HasForeignKey(s => s.RegistradoPorId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
