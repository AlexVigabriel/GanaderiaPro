namespace GanaderiaPro.Domain.Entities;

public enum SexoAnimal
{
    Macho,
    Hembra
}

public enum EstadoAnimal
{
    Activo,
    Vendido,
    Fallecido
}

public class Animal
{
    public Guid Id { get; set; }

    public Guid RanchoId { get; set; }
    public Rancho? Rancho { get; set; }

    public string Arete { get; set; } = string.Empty;
    public SexoAnimal Sexo { get; set; }
    public string Raza { get; set; } = string.Empty;
    public decimal? Peso { get; set; }
    public EstadoAnimal Estado { get; set; } = EstadoAnimal.Activo;
    public DateTime FechaRegistro { get; set; }

    public string? Nombre { get; set; }
    public DateOnly? FechaNacimiento { get; set; }
    public decimal? PesoNacimiento { get; set; }
    public string? Color { get; set; }
    public string? Observaciones { get; set; }
}
