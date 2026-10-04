using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-55: registro de pesajes.
public class PesajeServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();
    private static readonly DateOnly Hoy = DateOnly.FromDateTime(DateTime.UtcNow);

    private readonly Mock<IPesajeRepository> _pesajeRepoMock = new();
    private readonly Mock<IAnimalRepository> _animalRepoMock = new();
    private readonly Mock<IUnitOfWork> _unitOfWorkMock = new();

    private PesajeService CrearServicio()
    {
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        return new PesajeService(_pesajeRepoMock.Object, _animalRepoMock.Object, currentUserMock.Object, _unitOfWorkMock.Object);
    }

    private Animal AnimalDelRancho(EstadoAnimal estado = EstadoAnimal.Activo, decimal? peso = 300)
    {
        var animal = new Animal
        {
            Id = Guid.NewGuid(),
            RanchoId = RanchoIdDePrueba,
            Arete = "P-001",
            Estado = estado,
            Peso = peso,
            FechaNacimiento = Hoy.AddYears(-2),
        };
        _animalRepoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, animal.Id)).ReturnsAsync(animal);
        return animal;
    }

    [Fact]
    public async Task Registrar_PesajeMasReciente_ActualizaElPesoDelAnimal()
    {
        var animal = AnimalDelRancho();
        _pesajeRepoMock.Setup(r => r.ObtenerUltimaFechaAsync(animal.Id)).ReturnsAsync(Hoy.AddDays(-30));
        var service = CrearServicio();

        var resultado = await service.RegistrarAsync(animal.Id, new RegistrarPesajeRequest(345.5m, Hoy, " Balanza nueva "));

        Assert.Equal(345.5m, animal.Peso);
        Assert.Equal(345.5m, resultado.PesoActualAnimal);
        Assert.Equal("Balanza nueva", resultado.Pesaje.Observacion);
        _pesajeRepoMock.Verify(r => r.Agregar(It.Is<Pesaje>(p => p.AnimalId == animal.Id && p.Peso == 345.5m)), Times.Once);
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task Registrar_PrimerPesaje_ActualizaElPesoDelAnimal()
    {
        var animal = AnimalDelRancho(peso: null);
        var service = CrearServicio();

        await service.RegistrarAsync(animal.Id, new RegistrarPesajeRequest(120, Hoy.AddDays(-3)));

        Assert.Equal(120, animal.Peso);
    }

    [Fact]
    public async Task Registrar_PesajeConFechaAnterior_SeAgregaSinCambiarElPesoActual()
    {
        var animal = AnimalDelRancho(peso: 410);
        _pesajeRepoMock.Setup(r => r.ObtenerUltimaFechaAsync(animal.Id)).ReturnsAsync(Hoy);
        var service = CrearServicio();

        var resultado = await service.RegistrarAsync(animal.Id, new RegistrarPesajeRequest(380, Hoy.AddDays(-60)));

        Assert.Equal(410, animal.Peso);
        Assert.Equal(410, resultado.PesoActualAnimal);
        _pesajeRepoMock.Verify(r => r.Agregar(It.IsAny<Pesaje>()), Times.Once);
    }

    [Fact]
    public async Task Registrar_SegundoPesajeEnLaMismaFecha_LanzaExcepcion()
    {
        var animal = AnimalDelRancho();
        _pesajeRepoMock.Setup(r => r.ExisteEnFechaAsync(animal.Id, Hoy)).ReturnsAsync(true);
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(animal.Id, new RegistrarPesajeRequest(300, Hoy)));

        Assert.Contains("esa fecha", ex.Message);
        _pesajeRepoMock.Verify(r => r.Agregar(It.IsAny<Pesaje>()), Times.Never);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    [InlineData(1500.01)]
    public async Task Registrar_ConPesoFueraDeRango_LanzaExcepcion(decimal peso)
    {
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(animal.Id, new RegistrarPesajeRequest(peso, Hoy)));

        Assert.Contains("1500", ex.Message);
        _pesajeRepoMock.Verify(r => r.Agregar(It.IsAny<Pesaje>()), Times.Never);
    }

    [Fact]
    public async Task Registrar_ConFechaFutura_LanzaExcepcion()
    {
        // RN-14: no se registran fechas futuras.
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(animal.Id, new RegistrarPesajeRequest(300, Hoy.AddDays(2))));

        Assert.Contains("futura", ex.Message);
    }

    [Fact]
    public async Task Registrar_AnteriorAlNacimiento_LanzaExcepcion()
    {
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(animal.Id, new RegistrarPesajeRequest(300, Hoy.AddYears(-3))));

        Assert.Contains("nacimiento", ex.Message);
    }

    [Theory]
    [InlineData(EstadoAnimal.Vendido)]
    [InlineData(EstadoAnimal.Fallecido)]
    public async Task Registrar_DeAnimalDadoDeBaja_LanzaExcepcion(EstadoAnimal estado)
    {
        var animal = AnimalDelRancho(estado);
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(animal.Id, new RegistrarPesajeRequest(300, Hoy)));

        Assert.Contains("activos", ex.Message);
    }

    [Fact]
    public async Task Listar_DeAnimalDeOtroRancho_LanzaRecursoNoEncontrado()
    {
        // RN-16
        var service = CrearServicio();

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(() => service.ListarAsync(Guid.NewGuid()));
    }

    [Fact]
    public async Task EliminarAnimal_ConPesajes_LoImpideYSugiereLaBaja()
    {
        // RN-05: un animal con eventos no se borra; se registra su baja.
        var animal = AnimalDelRancho();
        _animalRepoMock.Setup(r => r.TieneEventosAsync(animal.Id)).ReturnsAsync(true);
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        var animalService = new AnimalService(_animalRepoMock.Object, currentUserMock.Object, _unitOfWorkMock.Object);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => animalService.EliminarAsync(animal.Id));

        Assert.Contains("baja", ex.Message);
        _animalRepoMock.Verify(r => r.Eliminar(It.IsAny<Animal>()), Times.Never);
    }

    private Pesaje PesajeDe(Animal animal, DateOnly fecha, decimal peso)
    {
        var pesaje = new Pesaje { Id = Guid.NewGuid(), AnimalId = animal.Id, Fecha = fecha, Peso = peso };
        _pesajeRepoMock.Setup(r => r.ObtenerPorIdAsync(animal.Id, pesaje.Id)).ReturnsAsync(pesaje);
        return pesaje;
    }

    [Fact]
    public async Task Editar_ElPesajeMasReciente_RecalculaElPesoActual()
    {
        var animal = AnimalDelRancho(peso: 666);
        var antiguo = PesajeDe(animal, Hoy.AddDays(-30), 333);
        var reciente = PesajeDe(animal, Hoy, 666);
        _pesajeRepoMock.Setup(r => r.ListarPorAnimalAsync(animal.Id)).ReturnsAsync(new List<Pesaje> { reciente, antiguo });
        var service = CrearServicio();

        var resultado = await service.EditarAsync(animal.Id, reciente.Id, new RegistrarPesajeRequest(366, Hoy, "Corregido"));

        Assert.Equal(366, reciente.Peso);
        Assert.Equal(366, animal.Peso);
        Assert.Equal(366, resultado.PesoActualAnimal);
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task Editar_AUnaFechaQueYaTieneOtroPesaje_LanzaExcepcion()
    {
        var animal = AnimalDelRancho();
        var pesaje = PesajeDe(animal, Hoy.AddDays(-5), 300);
        _pesajeRepoMock.Setup(r => r.ExisteEnFechaAsync(animal.Id, Hoy, pesaje.Id)).ReturnsAsync(true);
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.EditarAsync(animal.Id, pesaje.Id, new RegistrarPesajeRequest(300, Hoy)));
    }

    [Fact]
    public async Task Editar_SinCambiarLaFecha_SePermiteAunqueHayaOtroPesajeEseDia()
    {
        // Días repetidos cargados antes de la regla: corregir el peso no se bloquea.
        var animal = AnimalDelRancho();
        var pesaje = PesajeDe(animal, Hoy, 700);
        _pesajeRepoMock.Setup(r => r.ExisteEnFechaAsync(animal.Id, Hoy, pesaje.Id)).ReturnsAsync(true);
        _pesajeRepoMock.Setup(r => r.ListarPorAnimalAsync(animal.Id)).ReturnsAsync(new List<Pesaje> { pesaje });
        var service = CrearServicio();

        var resultado = await service.EditarAsync(animal.Id, pesaje.Id, new RegistrarPesajeRequest(788, Hoy));

        Assert.Equal(788, resultado.Pesaje.Peso);
    }

    [Fact]
    public async Task Eliminar_ElPesajeMasReciente_VuelveAlPesoDelAnterior()
    {
        var animal = AnimalDelRancho(peso: 55);
        var antiguo = PesajeDe(animal, Hoy.AddDays(-30), 333);
        var erroneo = PesajeDe(animal, Hoy, 55);
        _pesajeRepoMock.Setup(r => r.ListarPorAnimalAsync(animal.Id)).ReturnsAsync(new List<Pesaje> { erroneo, antiguo });
        var service = CrearServicio();

        var pesoActual = await service.EliminarAsync(animal.Id, erroneo.Id);

        Assert.Equal(333, pesoActual);
        _pesajeRepoMock.Verify(r => r.Eliminar(erroneo), Times.Once);
    }

    [Fact]
    public async Task Eliminar_ElUnicoPesaje_ConservaElUltimoPesoConocido()
    {
        var animal = AnimalDelRancho(peso: 300);
        var unico = PesajeDe(animal, Hoy, 300);
        _pesajeRepoMock.Setup(r => r.ListarPorAnimalAsync(animal.Id)).ReturnsAsync(new List<Pesaje> { unico });
        var service = CrearServicio();

        var pesoActual = await service.EliminarAsync(animal.Id, unico.Id);

        Assert.Equal(300, pesoActual);
    }

    [Fact]
    public async Task Eliminar_PesajeDeAnimalDadoDeBaja_LanzaExcepcion()
    {
        var animal = AnimalDelRancho(EstadoAnimal.Fallecido);
        var pesaje = PesajeDe(animal, Hoy.AddDays(-2), 300);
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.EliminarAsync(animal.Id, pesaje.Id));
        _pesajeRepoMock.Verify(r => r.Eliminar(It.IsAny<Pesaje>()), Times.Never);
    }

    [Fact]
    public async Task Eliminar_PesajeInexistente_LanzaRecursoNoEncontrado()
    {
        var animal = AnimalDelRancho();
        var service = CrearServicio();

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(() => service.EliminarAsync(animal.Id, Guid.NewGuid()));
    }
}
