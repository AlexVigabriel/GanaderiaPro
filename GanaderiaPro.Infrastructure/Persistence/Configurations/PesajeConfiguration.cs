using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class PesajeConfiguration : IEntityTypeConfiguration<Pesaje>
{
    public void Configure(EntityTypeBuilder<Pesaje> builder)
    {
        builder.ToTable("Pesajes");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.Peso)
            .HasPrecision(7, 2)
            .IsRequired();

        builder.Property(p => p.Observacion)
            .HasMaxLength(500);

        builder.HasIndex(p => new { p.AnimalId, p.Fecha });

        builder.HasOne(p => p.Animal)
            .WithMany()
            .HasForeignKey(p => p.AnimalId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
