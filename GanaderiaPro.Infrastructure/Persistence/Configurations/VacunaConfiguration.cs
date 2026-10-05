using GanaderiaPro.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace GanaderiaPro.Infrastructure.Persistence.Configurations;

public class VacunaConfiguration : IEntityTypeConfiguration<Vacuna>
{
    public void Configure(EntityTypeBuilder<Vacuna> builder)
    {
        builder.ToTable("Vacunas");
        builder.HasKey(v => v.Id);
        builder.Property(v => v.Nombre).IsRequired().HasMaxLength(100);
        builder.HasIndex(v => v.Nombre).IsUnique();

        // HU-26: catálogo precargado con las vacunas bovinas más comunes.
        // Ids fijos para que la migración no cambie en cada ejecución.
        builder.HasData(
            new Vacuna { Id = Guid.Parse("8f1a2b01-0000-4000-8000-000000000001"), Nombre = "Fiebre aftosa" },
            new Vacuna { Id = Guid.Parse("8f1a2b01-0000-4000-8000-000000000002"), Nombre = "Rabia bovina" },
            new Vacuna { Id = Guid.Parse("8f1a2b01-0000-4000-8000-000000000003"), Nombre = "Brucelosis" },
            new Vacuna { Id = Guid.Parse("8f1a2b01-0000-4000-8000-000000000004"), Nombre = "Carbunclo sintomático (mancha)" },
            new Vacuna { Id = Guid.Parse("8f1a2b01-0000-4000-8000-000000000005"), Nombre = "Clostridiosis polivalente" },
            new Vacuna { Id = Guid.Parse("8f1a2b01-0000-4000-8000-000000000006"), Nombre = "Leptospirosis" },
            new Vacuna { Id = Guid.Parse("8f1a2b01-0000-4000-8000-000000000007"), Nombre = "IBR-DVB (reproductiva)" },
            new Vacuna { Id = Guid.Parse("8f1a2b01-0000-4000-8000-000000000008"), Nombre = "Pasteurelosis" },
            new Vacuna { Id = Guid.Parse("8f1a2b01-0000-4000-8000-000000000009"), Nombre = "Carbunclo bacteridiano (ántrax)" });
    }
}
