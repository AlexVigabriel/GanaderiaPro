using GanaderiaPro.Application.Common;
using Xunit;

namespace GanaderiaPro.Tests;

// RC-07: las observaciones tienen que describir algo, no ser solo un número.
public class TextoDescriptivoTests
{
    [Theory]
    // Los ejemplos de la revisión docente que se aceptan.
    [InlineData("Animal nacido completamente sano")]
    [InlineData("Requiere chequeo médico en cuatro días")]
    [InlineData("Peso registrado: 40 kg")]
    [InlineData("Ñandú cerca del corral")]
    // Opcional: vacío sigue siendo válido.
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void Acepta_TextoQueDescribeAlgo(string? texto)
    {
        Assert.Null(TextoDescriptivo.Validar(texto, 500));
    }

    [Theory]
    // Los ejemplos de la revisión docente que se rechazan, y variantes.
    [InlineData("40")]
    [InlineData("60")]
    [InlineData("40,5")]
    [InlineData(" 12 ")]
    [InlineData("--")]
    [InlineData("4 x")]
    public void Rechaza_SoloNumerosOSignos(string texto)
    {
        Assert.Equal("La observación debe describir algo, no solo un número.", TextoDescriptivo.Validar(texto, 500));
    }

    [Fact]
    public void ElMensajeConcuerdaConElCampo()
    {
        Assert.Equal("Las observaciones deben describir algo, no solo un número.",
            TextoDescriptivo.Validar("40", 500, "Las observaciones"));
        Assert.Equal("La observación puede tener hasta 10 caracteres.",
            TextoDescriptivo.Validar("Animal muy tranquilo", 10));
    }
}
