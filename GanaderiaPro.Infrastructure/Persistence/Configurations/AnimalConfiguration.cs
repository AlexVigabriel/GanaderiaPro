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

        // HU-47: un mismo registro del dispositivo no se crea dos veces.
        builder.HasIndex(a => new { a.RanchoId, a.IdCliente })
            .IsUnique()
            .HasFilter("\"IdCliente\" IS NOT NULL");

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

        builder.Property(a => a.CausaMuerte)
            .HasConversion<string>()
            .HasMaxLength(30);

        builder.Property(a => a.DetalleCausaMuerte)
            .HasMaxLength(100);

        builder.Property(a => a.Sexo)
            .HasConversion<string>()
            .HasMaxLength(10)
            .IsRequired();

        builder.Property(a => a.Estado)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        // HU-23: si se borra el corral, el animal queda sin corral.
        builder.HasOne(a => a.Corral)
            .WithMany()
            .HasForeignKey(a => a.CorralId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne(a => a.Rancho)
            .WithMany(r => r.Animales)
            .HasForeignKey(a => a.RanchoId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
