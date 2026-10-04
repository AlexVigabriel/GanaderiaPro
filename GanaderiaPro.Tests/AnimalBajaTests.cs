using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-54: baja de un animal por venta o fallecimiento.
public class AnimalBajaTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();
    private static readonly DateOnly Hoy = DateOnly.FromDateTime(DateTime.UtcNow);

    private readonly Mock<IAnimalRepository> _repoMock = new();
    private readonly Mock<IUnitOfWork> _unitOfWorkMock = new();

    private AnimalService CrearServicio()
    {
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        return new AnimalService(_repoMock.Object, currentUserMock.Object, _unitOfWorkMock.Object);
    }

    private Animal AnimalDelRancho(EstadoAnimal estado = EstadoAnimal.Activo)
    {
        var animal = new Animal
        {
            Id = Guid.NewGuid(),
            RanchoId = RanchoIdDePrueba,
            Arete = "B-001",
            Sexo = SexoAnimal.Hembra,
            Raza = "Nelore",
            Estado = estado,
            FechaNacimiento = Hoy.AddYears(-3),
        };
        _repoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, animal.Id)).ReturnsAsync(animal);
        return animal;
    }

    [Theory]
    [InlineData(TipoBaja.Venta, EstadoAnimal.Vendido)]
    [InlineData(TipoBaja.Fallecimiento, EstadoAnimal.Fallecido)]
    public async Task RegistrarBaja_DeUnAnimalActivo_CambiaElEstadoYConservaSusDatos(TipoBaja tipo, EstadoAnimal esperado)
    {
        // RN-04: el animal no se borra, cambia de estado y conserva su historial.
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var resultado = await service.RegistrarBajaAsync(animal.Id, new RegistrarBajaRequest(tipo, Hoy, " Vendido en feria "));

        Assert.Equal(esperado, resultado.Estado);
        Assert.Equal(Hoy, resultado.FechaBaja);
        Assert.Equal("Vendido en feria", resultado.ObservacionBaja);
        Assert.Equal("B-001", resultado.Arete);
        _repoMock.Verify(r => r.Eliminar(It.IsAny<Animal>()), Times.Never);
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task RegistrarBaja_ConFechaFutura_LanzaExcepcion()
    {
        // RN-14: no se registran fechas futuras.
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarBajaAsync(animal.Id, new RegistrarBajaRequest(TipoBaja.Venta, Hoy.AddDays(2))));

        Assert.Contains("futura", ex.Message);
        Assert.Equal(EstadoAnimal.Activo, animal.Estado);
    }

    [Fact]
    public async Task RegistrarBaja_AnteriorAlNacimiento_LanzaExcepcion()
    {
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarBajaAsync(animal.Id, new RegistrarBajaRequest(TipoBaja.Fallecimiento, Hoy.AddYears(-4))));

        Assert.Contains("nacimiento", ex.Message);
    }

    [Fact]
    public async Task RegistrarBaja_DeUnAnimalYaDadoDeBaja_LanzaExcepcion()
    {
        var animal = AnimalDelRancho(EstadoAnimal.Vendido);
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarBajaAsync(animal.Id, new RegistrarBajaRequest(TipoBaja.Fallecimiento, Hoy)));

        Assert.Contains("activo", ex.Message);
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Never);
    }

    [Fact]
    public async Task RegistrarBaja_DeOtroRancho_LanzaRecursoNoEncontrado()
    {
        // RN-16: un animal de otro rancho se trata como inexistente.
        var service = CrearServicio();

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(
            () => service.RegistrarBajaAsync(Guid.NewGuid(), new RegistrarBajaRequest(TipoBaja.Venta, Hoy)));
    }
}
