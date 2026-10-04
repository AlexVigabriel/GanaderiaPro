using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-54: baja de un animal (fallecimiento desde la calavera; venta, fallecimiento
// o vuelta a Activo desde Editar).
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

    private static CambiarEstadoRequest Fallecido(DateOnly fecha, CausaMuerte? causa = CausaMuerte.Enfermedad, string? detalle = null) =>
        new(EstadoAnimal.Fallecido, fecha, " Revisado por el veterinario ", causa, detalle);

    [Fact]
    public async Task RegistrarBaja_PorFallecimiento_CambiaElEstadoYConservaSusDatos()
    {
        // RN-04: el animal no se borra, cambia de estado y conserva su historial.
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var resultado = await service.RegistrarBajaAsync(animal.Id, Fallecido(Hoy));

        Assert.Equal(EstadoAnimal.Fallecido, resultado.Estado);
        Assert.Equal(Hoy, resultado.FechaBaja);
        Assert.Equal(CausaMuerte.Enfermedad, resultado.CausaMuerte);
        Assert.Equal("Revisado por el veterinario", resultado.ObservacionBaja);
        Assert.Equal("B-001", resultado.Arete);
        _repoMock.Verify(r => r.Eliminar(It.IsAny<Animal>()), Times.Never);
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task RegistrarBaja_SinCausaDeMuerte_LanzaExcepcion()
    {
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarBajaAsync(animal.Id, Fallecido(Hoy, causa: null)));

        Assert.Contains("causa", ex.Message);
        Assert.Equal(EstadoAnimal.Activo, animal.Estado);
    }

    [Fact]
    public async Task RegistrarBaja_ConCausaOtraSinDetalle_LanzaExcepcion()
    {
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarBajaAsync(animal.Id, Fallecido(Hoy, CausaMuerte.Otra, "  ")));
    }

    [Fact]
    public async Task RegistrarBaja_ConCausaOtra_GuardaElDetalleEscrito()
    {
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var resultado = await service.RegistrarBajaAsync(animal.Id, Fallecido(Hoy, CausaMuerte.Otra, " Mordedura de víbora "));

        Assert.Equal(CausaMuerte.Otra, resultado.CausaMuerte);
        Assert.Equal("Mordedura de víbora", resultado.DetalleCausaMuerte);
    }

    [Fact]
    public async Task RegistrarBaja_ConFechaFutura_LanzaExcepcion()
    {
        // RN-14: no se registran fechas futuras.
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarBajaAsync(animal.Id, Fallecido(Hoy.AddDays(2))));

        Assert.Contains("futura", ex.Message);
    }

    [Fact]
    public async Task RegistrarBaja_AnteriorAlNacimiento_LanzaExcepcion()
    {
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarBajaAsync(animal.Id, Fallecido(Hoy.AddYears(-4))));

        Assert.Contains("nacimiento", ex.Message);
    }

    [Fact]
    public async Task RegistrarBaja_DeUnAnimalYaDadoDeBaja_LanzaExcepcion()
    {
        var animal = AnimalDelRancho(EstadoAnimal.Vendido);
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarBajaAsync(animal.Id, Fallecido(Hoy)));

        Assert.Contains("activo", ex.Message);
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Never);
    }

    [Fact]
    public async Task RegistrarBaja_DeOtroRancho_LanzaRecursoNoEncontrado()
    {
        // RN-16: un animal de otro rancho se trata como inexistente.
        var service = CrearServicio();

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(
            () => service.RegistrarBajaAsync(Guid.NewGuid(), Fallecido(Hoy)));
    }

    [Fact]
    public async Task CambiarEstado_AVendidoSinFecha_LanzaExcepcion()
    {
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.CambiarEstadoAsync(animal.Id, new CambiarEstadoRequest(EstadoAnimal.Vendido)));

        Assert.Contains("fecha de venta", ex.Message);
    }

    [Fact]
    public async Task CambiarEstado_AVendido_NoGuardaCausaDeMuerte()
    {
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var resultado = await service.CambiarEstadoAsync(
            animal.Id, new CambiarEstadoRequest(EstadoAnimal.Vendido, Hoy, "Feria", CausaMuerte.Accidente));

        Assert.Equal(EstadoAnimal.Vendido, resultado.Estado);
        Assert.Null(resultado.CausaMuerte);
    }

    [Fact]
    public async Task CambiarEstado_DeVueltaAActivo_BorraLosDatosDeLaBaja()
    {
        // Para corregir una baja registrada por error.
        var animal = AnimalDelRancho(EstadoAnimal.Fallecido);
        animal.FechaBaja = Hoy;
        animal.CausaMuerte = CausaMuerte.Clima;
        animal.ObservacionBaja = "Rayo";
        var service = CrearServicio();

        var resultado = await service.CambiarEstadoAsync(animal.Id, new CambiarEstadoRequest(EstadoAnimal.Activo));

        Assert.Equal(EstadoAnimal.Activo, resultado.Estado);
        Assert.Null(resultado.FechaBaja);
        Assert.Null(resultado.CausaMuerte);
        Assert.Null(resultado.ObservacionBaja);
    }
}
