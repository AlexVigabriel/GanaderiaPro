using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class NotificacionConfiguration : IEntityTypeConfiguration<Notificacion>
{
    public void Configure(EntityTypeBuilder<Notificacion> builder)
    {
        builder.ToTable("Notificaciones");

        builder.HasKey(n => n.Id);

        builder.Property(n => n.Tipo)
            .HasConversion<string>()
            .HasMaxLength(30)
            .IsRequired();

        builder.Property(n => n.Mensaje).IsRequired().HasMaxLength(300);
        builder.Property(n => n.ReferenciaTipo).IsRequired().HasMaxLength(30);
        builder.Property(n => n.Clave).IsRequired().HasMaxLength(150);

        // HU-40: cada usuario recibe una sola vez la alerta de un mismo hecho.
        builder.HasIndex(n => new { n.UsuarioId, n.Clave })
            .IsUnique();

        // Para contar rápido las no leídas.
        builder.HasIndex(n => new { n.UsuarioId, n.Leida });

        builder.HasOne(n => n.Usuario)
            .WithMany()
            .HasForeignKey(n => n.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
