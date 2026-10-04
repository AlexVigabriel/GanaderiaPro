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

// HU-54: motivo de la baja. Define si el animal pasa a Vendido o a Fallecido.
public enum TipoBaja
{
    Venta,
    Fallecimiento
}

// HU-74: categoría productiva según sexo, edad y castración.
public enum CategoriaAnimal
{
    Ternero,
    Ternera,
    Torito,
    Vaquillona,
    Novillo,
    Toro,
    Vaca
}

public class Animal
{
    private const int MesesFinTernero = 8;
    private const int MesesAdulto = 24;

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

    // Solo aplica a machos; define si es Novillo en vez de Torito o Toro.
    public bool Castrado { get; set; }

    // HU-54: datos de la baja (venta o fallecimiento). Vacíos mientras está Activo.
    public DateOnly? FechaBaja { get; set; }
    public string? ObservacionBaja { get; set; }

    // La categoría no se guarda: cambia sola con la edad, así que se calcula
    // a la fecha pedida. Sin fecha de nacimiento no se puede calcular.
    public CategoriaAnimal? CategoriaAl(DateOnly hoy)
    {
        if (FechaNacimiento is not { } nacimiento)
        {
            return null;
        }

        var meses = MesesCumplidos(nacimiento, hoy);
        var esMacho = Sexo == SexoAnimal.Macho;

        if (meses < MesesFinTernero)
        {
            return esMacho ? CategoriaAnimal.Ternero : CategoriaAnimal.Ternera;
        }

        if (!esMacho)
        {
            return meses < MesesAdulto ? CategoriaAnimal.Vaquillona : CategoriaAnimal.Vaca;
        }

        if (Castrado)
        {
            return CategoriaAnimal.Novillo;
        }

        return meses < MesesAdulto ? CategoriaAnimal.Torito : CategoriaAnimal.Toro;
    }

    private static int MesesCumplidos(DateOnly desde, DateOnly hasta)
    {
        var meses = (hasta.Year - desde.Year) * 12 + hasta.Month - desde.Month;
        return hasta.Day < desde.Day ? meses - 1 : meses;
    }
}
