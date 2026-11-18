using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class MovimientoCorralConfiguration : IEntityTypeConfiguration<MovimientoCorral>
{
    public void Configure(EntityTypeBuilder<MovimientoCorral> builder)
    {
        builder.ToTable("MovimientosCorral");

        builder.HasKey(m => m.Id);

        builder.Property(m => m.CorralOrigen).HasMaxLength(60);
        builder.Property(m => m.CorralDestino).HasMaxLength(60);

        builder.HasIndex(m => new { m.AnimalId, m.Fecha });

        builder.HasOne(m => m.Animal)
            .WithMany()
            .HasForeignKey(m => m.AnimalId)
            .OnDelete(DeleteBehavior.Cascade);

        // El historial no se pierde si se borra un usuario.
        builder.HasOne(m => m.Usuario)
            .WithMany()
            .HasForeignKey(m => m.UsuarioId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
