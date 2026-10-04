using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class AnimalConfiguration : IEntityTypeConfiguration<Animal>
{
    public void Configure(EntityTypeBuilder<Animal> builder)
    {
        builder.ToTable("Animales");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.Arete)
            .IsRequired()
            .HasMaxLength(50);

        // RN-01: el arete es único dentro de cada rancho (no globalmente).
        builder.HasIndex(a => new { a.RanchoId, a.Arete })
            .IsUnique();

        builder.Property(a => a.Raza)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(a => a.Peso)
            .HasPrecision(7, 2);

        builder.Property(a => a.Nombre)
            .HasMaxLength(100);

        builder.Property(a => a.PesoNacimiento)
            .HasPrecision(7, 2);

        builder.Property(a => a.Color)
            .HasMaxLength(40);

        builder.Property(a => a.Observaciones)
            .HasMaxLength(500);

        builder.Property(a => a.ObservacionBaja)
            .HasMaxLength(500);

        builder.Property(a => a.Sexo)
            .HasConversion<string>()
            .HasMaxLength(10)
            .IsRequired();

        builder.Property(a => a.Estado)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        builder.HasOne(a => a.Rancho)
            .WithMany(r => r.Animales)
            .HasForeignKey(a => a.RanchoId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
