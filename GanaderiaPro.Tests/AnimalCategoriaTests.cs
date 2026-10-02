using GanaderiaPro.Domain.Entities;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-74: la categoría sale del sexo, la edad y si el macho está castrado.
public class AnimalCategoriaTests
{
    private static readonly DateOnly Hoy = new(2026, 10, 2);

    private static Animal Nacido(SexoAnimal sexo, int mesesAtras, bool castrado = false) => new()
    {
        Sexo = sexo,
        Castrado = castrado,
        FechaNacimiento = Hoy.AddMonths(-mesesAtras),
    };

    [Theory]
    [InlineData(SexoAnimal.Macho, 0, false, CategoriaAnimal.Ternero)]
    [InlineData(SexoAnimal.Hembra, 7, false, CategoriaAnimal.Ternera)]
    [InlineData(SexoAnimal.Macho, 8, false, CategoriaAnimal.Torito)]
    [InlineData(SexoAnimal.Hembra, 8, false, CategoriaAnimal.Vaquillona)]
    [InlineData(SexoAnimal.Macho, 23, false, CategoriaAnimal.Torito)]
    [InlineData(SexoAnimal.Hembra, 23, false, CategoriaAnimal.Vaquillona)]
    [InlineData(SexoAnimal.Macho, 24, false, CategoriaAnimal.Toro)]
    [InlineData(SexoAnimal.Hembra, 24, false, CategoriaAnimal.Vaca)]
    [InlineData(SexoAnimal.Macho, 7, true, CategoriaAnimal.Ternero)]
    [InlineData(SexoAnimal.Macho, 8, true, CategoriaAnimal.Novillo)]
    [InlineData(SexoAnimal.Macho, 60, true, CategoriaAnimal.Novillo)]
    public void CategoriaAl_SegunSexoEdadYCastracion(SexoAnimal sexo, int meses, bool castrado, CategoriaAnimal esperada)
    {
        var animal = Nacido(sexo, meses, castrado);

        Assert.Equal(esperada, animal.CategoriaAl(Hoy));
    }

    [Fact]
    public void CategoriaAl_UnDiaAntesDeCumplir8Meses_SigueSiendoTernero()
    {
        var animal = new Animal { Sexo = SexoAnimal.Macho, FechaNacimiento = Hoy.AddMonths(-8).AddDays(1) };

        Assert.Equal(CategoriaAnimal.Ternero, animal.CategoriaAl(Hoy));
    }

    [Fact]
    public void CategoriaAl_SinFechaDeNacimiento_NoTieneCategoria()
    {
        var animal = new Animal { Sexo = SexoAnimal.Hembra };

        Assert.Null(animal.CategoriaAl(Hoy));
    }
}
