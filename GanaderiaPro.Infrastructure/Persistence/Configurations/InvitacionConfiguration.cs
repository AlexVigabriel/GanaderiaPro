using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class InvitacionConfiguration : IEntityTypeConfiguration<Invitacion>
{
    public void Configure(EntityTypeBuilder<Invitacion> builder)
    {
        builder.ToTable("Invitaciones");
        builder.HasKey(i => i.Id);

        builder.Property(i => i.CodigoHash).IsRequired().HasMaxLength(64);
        builder.HasIndex(i => i.CodigoHash).IsUnique();

        builder.HasOne(i => i.Usuario)
            .WithMany()
            .HasForeignKey(i => i.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
