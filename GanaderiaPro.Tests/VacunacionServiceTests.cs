using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-26: registro de vacunaciones.
public class VacunacionServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();
    private static readonly Guid VeterinarioId = Guid.NewGuid();
    private static readonly DateOnly Hoy = FechaRancho.Hoy();
    private static readonly Vacuna Aftosa = new() { Id = Guid.NewGuid(), Nombre = "Fiebre aftosa" };

    private readonly Mock<IVacunacionRepository> _vacunacionRepoMock = new();
    private readonly Mock<IAnimalRepository> _animalRepoMock = new();
    private readonly Mock<IUnitOfWork> _unitOfWorkMock = new();

    public VacunacionServiceTests()
    {
        _vacunacionRepoMock.Setup(r => r.ObtenerVacunaAsync(Aftosa.Id)).ReturnsAsync(Aftosa);
        // Por defecto, sin vacunaciones previas.
        _vacunacionRepoMock
            .Setup(r => r.ListarPorAnimalesYVacunaAsync(It.IsAny<IReadOnlyList<Guid>>(), It.IsAny<Guid>()))
            .ReturnsAsync(new List<Vacunacion>());
    }

    private VacunacionService CrearServicio()
    {
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        currentUserMock.Setup(c => c.UsuarioId).Returns(VeterinarioId);
        return new VacunacionService(_vacunacionRepoMock.Object, _animalRepoMock.Object, currentUserMock.Object, _unitOfWorkMock.Object);
    }

    private Animal AnimalDelRancho(string arete, EstadoAnimal estado = EstadoAnimal.Activo)
    {
        var animal = new Animal
        {
            Id = Guid.NewGuid(),
            RanchoId = RanchoIdDePrueba,
            Arete = arete,
            Estado = estado,
            FechaNacimiento = Hoy.AddYears(-2),
        };
        _animalRepoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, animal.Id)).ReturnsAsync(animal);
        return animal;
    }

    private static RegistrarVacunacionRequest Pedido(IEnumerable<Animal> animales, DateOnly? aplicacion = null, DateOnly? proxima = null) =>
        new(animales.Select(a => a.Id).ToList(), Aftosa.Id, "5 ml", aplicacion ?? Hoy, proxima, "Campaña de octubre");

    [Fact]
    public async Task Registrar_VariosAnimales_CreaUnaVacunacionPorAnimalConElUsuarioComoVeterinario()
    {
        var a1 = AnimalDelRancho("V-01");
        var a2 = AnimalDelRancho("V-02");
        var service = CrearServicio();

        var resultado = await service.RegistrarAsync(Pedido([a1, a2], proxima: Hoy.AddMonths(6)));

        Assert.Equal(new[] { "V-01", "V-02" }, resultado.Select(r => r.Arete));
        Assert.All(resultado, r => Assert.Equal("Fiebre aftosa", r.Vacuna));
        _vacunacionRepoMock.Verify(r => r.Agregar(It.Is<Vacunacion>(v => v.VeterinarioId == VeterinarioId)), Times.Exactly(2));
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task Registrar_ConFechaDeAplicacionFutura_LanzaExcepcion()
    {
        // RN-14: no se registran fechas futuras.
        var animal = AnimalDelRancho("V-03");
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(Pedido([animal], aplicacion: Hoy.AddDays(1))));

        Assert.Contains("futura", ex.Message);
    }

    [Fact]
    public async Task Registrar_ConProximaDosisAnteriorALaAplicacion_LanzaExcepcion()
    {
        var animal = AnimalDelRancho("V-04");
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(Pedido([animal], aplicacion: Hoy, proxima: Hoy.AddDays(-1))));

        Assert.Contains("próxima dosis", ex.Message);
    }

    [Fact]
    public async Task Registrar_ProximaDosisElMismoDia_SePermite()
    {
        var animal = AnimalDelRancho("V-05");
        var service = CrearServicio();

        var resultado = await service.RegistrarAsync(Pedido([animal], aplicacion: Hoy, proxima: Hoy));

        Assert.Single(resultado);
    }

    [Theory]
    [InlineData(EstadoAnimal.Vendido)]
    [InlineData(EstadoAnimal.Fallecido)]
    public async Task Registrar_ConUnAnimalDadoDeBaja_NoRegistraNinguno(EstadoAnimal estado)
    {
        // Todo o nada: si un animal no se puede vacunar, no se guarda ninguno.
        var activo = AnimalDelRancho("V-06");
        var deBaja = AnimalDelRancho("V-07", estado);
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(Pedido([activo, deBaja])));

        Assert.Contains("V-07", ex.Message);
        _vacunacionRepoMock.Verify(r => r.Agregar(It.IsAny<Vacunacion>()), Times.Never);
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Never);
    }

    [Fact]
    public async Task Registrar_SinAnimales_LanzaExcepcion()
    {
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(Pedido([])));
    }

    [Fact]
    public async Task Registrar_SinDosis_LanzaExcepcion()
    {
        var animal = AnimalDelRancho("V-08");
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(new RegistrarVacunacionRequest([animal.Id], Aftosa.Id, "  ", Hoy)));

        Assert.Contains("dosis", ex.Message);
    }

    [Fact]
    public async Task Registrar_ConVacunaInexistente_LanzaExcepcion()
    {
        var animal = AnimalDelRancho("V-09");
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(new RegistrarVacunacionRequest([animal.Id], Guid.NewGuid(), "5 ml", Hoy)));
    }

    [Fact]
    public async Task Registrar_AnimalDeOtroRancho_LanzaRecursoNoEncontrado()
    {
        // RN-16
        var service = CrearServicio();

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(
            () => service.RegistrarAsync(new RegistrarVacunacionRequest([Guid.NewGuid()], Aftosa.Id, "5 ml", Hoy)));
    }

    [Fact]
    public async Task Eliminar_VacunacionDeAnimalDadoDeBaja_LanzaExcepcion()
    {
        var animal = AnimalDelRancho("V-10", EstadoAnimal.Fallecido);
        var vacunacion = new Vacunacion { Id = Guid.NewGuid(), AnimalId = animal.Id, Animal = animal };
        _vacunacionRepoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, vacunacion.Id)).ReturnsAsync(vacunacion);
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.EliminarAsync(vacunacion.Id));
        _vacunacionRepoMock.Verify(r => r.Eliminar(It.IsAny<Vacunacion>()), Times.Never);
    }

    private void HistorialDe(params Vacunacion[] previas) =>
        _vacunacionRepoMock
            .Setup(r => r.ListarPorAnimalesYVacunaAsync(It.IsAny<IReadOnlyList<Guid>>(), Aftosa.Id))
            .ReturnsAsync(previas.ToList());

    private static Vacunacion Previa(Animal animal, DateOnly aplicacion, DateOnly? proxima = null) =>
        new() { Id = Guid.NewGuid(), AnimalId = animal.Id, VacunaId = Aftosa.Id, FechaAplicacion = aplicacion, FechaProximaDosis = proxima };

    [Fact]
    public async Task Verificar_LaMismaVacunaElMismoDia_EsUnBloqueo()
    {
        var animal = AnimalDelRancho("R-01");
        HistorialDe(Previa(animal, Hoy));
        var service = CrearServicio();

        var resultado = await service.VerificarAsync(Pedido([animal]));

        Assert.Single(resultado.Bloqueos);
        Assert.Contains("ya recibió", resultado.Bloqueos[0].Motivo);
        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(Pedido([animal]) with { Confirmado = true }));
    }

    [Fact]
    public async Task Verificar_ConDosisProgramadaAFuturo_AvisaLaFecha()
    {
        var animal = AnimalDelRancho("R-02");
        HistorialDe(Previa(animal, Hoy.AddMonths(-5), proxima: Hoy.AddMonths(1)));
        var service = CrearServicio();

        var resultado = await service.VerificarAsync(Pedido([animal]));

        Assert.Empty(resultado.Bloqueos);
        Assert.Contains("programada", Assert.Single(resultado.Avisos).Motivo);
    }

    [Fact]
    public async Task Verificar_AplicadaHaceMenosDe30Dias_AvisaLosDias()
    {
        var animal = AnimalDelRancho("R-03");
        HistorialDe(Previa(animal, Hoy.AddDays(-15)));
        var service = CrearServicio();

        var resultado = await service.VerificarAsync(Pedido([animal]));

        Assert.Contains("hace 15 días", Assert.Single(resultado.Avisos).Motivo);
    }

    [Fact]
    public async Task Verificar_AplicadaHaceMasDe30DiasYSinPendiente_NoAvisa()
    {
        var animal = AnimalDelRancho("R-04");
        HistorialDe(Previa(animal, Hoy.AddDays(-40), proxima: Hoy.AddDays(-5)));
        var service = CrearServicio();

        var resultado = await service.VerificarAsync(Pedido([animal]));

        Assert.Empty(resultado.Bloqueos);
        Assert.Empty(resultado.Avisos);
    }

    [Fact]
    public async Task Registrar_ConAvisosSinConfirmar_NoRegistraYConConfirmacionSi()
    {
        var animal = AnimalDelRancho("R-05");
        HistorialDe(Previa(animal, Hoy.AddDays(-10)));
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(Pedido([animal])));
        _vacunacionRepoMock.Verify(r => r.Agregar(It.IsAny<Vacunacion>()), Times.Never);

        var resultado = await service.RegistrarAsync(Pedido([animal]) with { Confirmado = true });

        Assert.Single(resultado);
    }
}
