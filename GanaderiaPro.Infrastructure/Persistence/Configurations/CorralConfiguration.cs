using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class CorralConfiguration : IEntityTypeConfiguration<Corral>
{
    public void Configure(EntityTypeBuilder<Corral> builder)
    {
        builder.ToTable("Corrales");
        builder.HasKey(c => c.Id);

        builder.Property(c => c.Nombre).IsRequired().HasMaxLength(60);

        // RN-06: el nombre del corral es único dentro de cada rancho.
        builder.HasIndex(c => new { c.RanchoId, c.Nombre }).IsUnique();

        builder.HasOne(c => c.Rancho)
            .WithMany()
            .HasForeignKey(c => c.RanchoId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
