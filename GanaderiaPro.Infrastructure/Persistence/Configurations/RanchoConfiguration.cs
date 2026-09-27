using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class RanchoConfiguration : IEntityTypeConfiguration<Rancho>
{
    public void Configure(EntityTypeBuilder<Rancho> builder)
    {
        builder.ToTable("Ranchos");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.Nombre)
            .IsRequired()
            .HasMaxLength(150);

        builder.Property(r => r.Plan)
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();
    }
}
