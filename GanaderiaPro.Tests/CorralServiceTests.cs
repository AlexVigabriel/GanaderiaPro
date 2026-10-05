using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-23 y HU-24: corrales.
public class CorralServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();

    private readonly Mock<ICorralRepository> _corralRepoMock = new();
    private readonly Mock<IAnimalRepository> _animalRepoMock = new();
    private readonly Mock<IUnitOfWork> _unitOfWorkMock = new();

    public CorralServiceTests()
    {
        _corralRepoMock.Setup(r => r.ListarAnimalesActivosAsync(It.IsAny<Guid>())).ReturnsAsync(new List<Animal>());
        _corralRepoMock.Setup(r => r.ContarAnimalesActivosAsync(RanchoIdDePrueba)).ReturnsAsync(new Dictionary<Guid, int>());
    }

    private CorralService CrearServicio()
    {
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        return new CorralService(_corralRepoMock.Object, _animalRepoMock.Object, currentUserMock.Object, _unitOfWorkMock.Object);
    }

    private Animal AnimalDelRancho(string arete, EstadoAnimal estado = EstadoAnimal.Activo)
    {
        var animal = new Animal { Id = Guid.NewGuid(), RanchoId = RanchoIdDePrueba, Arete = arete, Estado = estado };
        _animalRepoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, animal.Id)).ReturnsAsync(animal);
        return animal;
    }

    private Corral CorralDelRancho(string nombre, int capacidad, params Animal[] animales)
    {
        var corral = new Corral { Id = Guid.NewGuid(), RanchoId = RanchoIdDePrueba, Nombre = nombre, Capacidad = capacidad, Activo = true };
        _corralRepoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, corral.Id)).ReturnsAsync(corral);
        _corralRepoMock.Setup(r => r.ListarAnimalesActivosAsync(corral.Id)).ReturnsAsync(animales.ToList());
        return corral;
    }

    [Fact]
    public async Task Crear_SinAnimales_QuedaActivoConCeroAnimales()
    {
        var service = CrearServicio();

        var corral = await service.CrearAsync(new CrearCorralRequest("  Corral Norte ", 25));

        Assert.Equal("Corral Norte", corral.Nombre);
        Assert.True(corral.Activo);
        Assert.Equal(0, corral.AnimalesActivos);
        Assert.Equal(0, corral.PorcentajeOcupacion);
        _corralRepoMock.Verify(r => r.Agregar(It.Is<Corral>(c => c.RanchoId == RanchoIdDePrueba)), Times.Once);
    }

    [Fact]
    public async Task Crear_ConNombreRepetido_LanzaExcepcion()
    {
        // RN-06
        _corralRepoMock.Setup(r => r.ExisteNombreAsync(RanchoIdDePrueba, "Corral Norte", null)).ReturnsAsync(true);
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.CrearAsync(new CrearCorralRequest("Corral Norte", 10)));

        Assert.Equal("Ya existe un corral con ese nombre.", ex.Message);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-3)]
    public async Task Crear_ConCapacidadMenorQueUno_LanzaExcepcion(int capacidad)
    {
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.CrearAsync(new CrearCorralRequest("Corral Sur", capacidad)));
    }

    [Fact]
    public async Task Crear_ConMasAnimalesQueLaCapacidad_BloqueaEIndicaLosLugares()
    {
        // RN-07
        var animales = new[] { AnimalDelRancho("C-1"), AnimalDelRancho("C-2"), AnimalDelRancho("C-3") };
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.CrearAsync(new CrearCorralRequest("Corral Chico", 2, animales.Select(a => a.Id).ToList())));

        Assert.Contains("quedan 2 lugares", ex.Message);
        Assert.All(animales, a => Assert.Null(a.CorralId));
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Never);
    }

    [Fact]
    public async Task Crear_ConAnimales_LosAsignaAunqueEstuvieranEnOtroCorral()
    {
        var a1 = AnimalDelRancho("C-4");
        var a2 = AnimalDelRancho("C-5");
        a2.CorralId = Guid.NewGuid();
        var service = CrearServicio();

        var corral = await service.CrearAsync(new CrearCorralRequest("Corral Este", 4, [a1.Id, a2.Id]));

        Assert.Equal(corral.Id, a1.CorralId);
        Assert.Equal(corral.Id, a2.CorralId);
        Assert.Equal(2, corral.AnimalesActivos);
        Assert.Equal(50, corral.PorcentajeOcupacion);
    }

    [Fact]
    public async Task Crear_ConAnimalDeOtroRancho_LanzaRecursoNoEncontrado()
    {
        // RN-16
        var service = CrearServicio();

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(
            () => service.CrearAsync(new CrearCorralRequest("Corral Oeste", 5, [Guid.NewGuid()])));
    }

    [Fact]
    public async Task Crear_ConAnimalDadoDeBaja_LanzaExcepcion()
    {
        var vendido = AnimalDelRancho("C-6", EstadoAnimal.Vendido);
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.CrearAsync(new CrearCorralRequest("Corral X", 5, [vendido.Id])));
    }

    [Fact]
    public async Task Listar_CuentaSoloActivosYCalculaLaOcupacion()
    {
        // HU-24 / RN-04: las bajas no se cuentan (el repositorio cuenta solo activos).
        var norte = CorralDelRancho("Corral Norte", 25);
        var sur = CorralDelRancho("Corral Sur", 3);
        _corralRepoMock.Setup(r => r.ListarAsync(RanchoIdDePrueba, false)).ReturnsAsync(new List<Corral> { norte, sur });
        _corralRepoMock.Setup(r => r.ContarAnimalesActivosAsync(RanchoIdDePrueba))
            .ReturnsAsync(new Dictionary<Guid, int> { [norte.Id] = 18 });
        var service = CrearServicio();

        var corrales = await service.ListarAsync();

        Assert.Equal((18, 72), (corrales[0].AnimalesActivos, corrales[0].PorcentajeOcupacion));
        Assert.Equal((0, 0), (corrales[1].AnimalesActivos, corrales[1].PorcentajeOcupacion));
    }

    [Fact]
    public async Task Editar_ConCapacidadMenorALosAnimalesQueTiene_LanzaExcepcion()
    {
        var corral = CorralDelRancho("Corral Norte", 5, AnimalDelRancho("C-7"), AnimalDelRancho("C-8"), AnimalDelRancho("C-9"));
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.EditarAsync(corral.Id, new EditarCorralRequest("Corral Norte", 2)));

        Assert.Contains("tiene 3 animales", ex.Message);
    }

    [Fact]
    public async Task Desactivar_CorralConAnimales_LoBloqueaEIndicaCuantosReasignar()
    {
        // RN-08: solo se desactiva un corral vacío.
        var animal = AnimalDelRancho("C-10");
        var corral = CorralDelRancho("Corral Viejo", 5, animal, AnimalDelRancho("C-11"));
        animal.CorralId = corral.Id;
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.CambiarEstadoAsync(corral.Id, activo: false));

        Assert.Contains("tiene 2 animales", ex.Message);
        Assert.True(corral.Activo);
        Assert.Equal(corral.Id, animal.CorralId);
    }

    [Fact]
    public async Task Desactivar_CorralVacio_LoDesactiva()
    {
        var corral = CorralDelRancho("Corral Vacío", 5);
        var service = CrearServicio();

        var resultado = await service.CambiarEstadoAsync(corral.Id, activo: false);

        Assert.False(resultado.Activo);
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task AsignarAnimal_ACorralConLugar_LoMueve()
    {
        var animal = AnimalDelRancho("C-12");
        animal.CorralId = Guid.NewGuid();
        var destino = CorralDelRancho("Corral Destino", 2, AnimalDelRancho("C-13"));
        var service = CrearServicio();

        await service.AsignarAnimalAsync(animal.Id, destino.Id);

        Assert.Equal(destino.Id, animal.CorralId);
    }

    [Fact]
    public async Task AsignarAnimal_ACorralLleno_LoBloquea()
    {
        // RN-07
        var animal = AnimalDelRancho("C-14");
        var lleno = CorralDelRancho("Corral Lleno", 1, AnimalDelRancho("C-15"));
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.AsignarAnimalAsync(animal.Id, lleno.Id));

        Assert.Contains("lleno (1/1)", ex.Message);
        Assert.Null(animal.CorralId);
    }

    [Fact]
    public async Task AsignarAnimal_ACorralDesactivado_LoBloquea()
    {
        var animal = AnimalDelRancho("C-16");
        var inactivo = CorralDelRancho("Corral Cerrado", 5);
        inactivo.Activo = false;
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.AsignarAnimalAsync(animal.Id, inactivo.Id));
    }

    [Fact]
    public async Task AsignarAnimal_SinCorral_LoSacaDelCorral()
    {
        var animal = AnimalDelRancho("C-17");
        animal.CorralId = Guid.NewGuid();
        var service = CrearServicio();

        await service.AsignarAnimalAsync(animal.Id, null);

        Assert.Null(animal.CorralId);
    }

    [Fact]
    public async Task AsignarAnimal_DadoDeBaja_LoBloquea()
    {
        var vendido = AnimalDelRancho("C-18", EstadoAnimal.Vendido);
        var corral = CorralDelRancho("Corral Z", 5);
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.AsignarAnimalAsync(vendido.Id, corral.Id));
    }

    [Fact]
    public async Task AsignarAnimal_ACorralDeOtroRancho_LanzaRecursoNoEncontrado()
    {
        // RN-16
        var animal = AnimalDelRancho("C-19");
        var service = CrearServicio();

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(() => service.AsignarAnimalAsync(animal.Id, Guid.NewGuid()));
    }
}
