using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-12: indicadores generales del rancho.
public class TableroServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();
    private static readonly DateOnly Hoy = FechaRancho.Hoy();
    private static readonly Vacuna Aftosa = new() { Id = Guid.NewGuid(), Nombre = "Fiebre aftosa" };

    private readonly Mock<IAnimalRepository> _animales = new();
    private readonly Mock<IVacunacionRepository> _vacunaciones = new();
    private readonly Mock<IPrenezRepository> _preneces = new();
    private readonly Mock<ICorralRepository> _corrales = new();

    public TableroServiceTests()
    {
        // Por defecto, un rancho sin datos.
        _animales.Setup(r => r.ContarPorEstadoYSexoAsync(RanchoIdDePrueba)).ReturnsAsync(new List<ConteoAnimales>());
        _animales.Setup(r => r.ContarFallecidosDesdeAsync(RanchoIdDePrueba, It.IsAny<DateOnly>())).ReturnsAsync(0);
        _vacunaciones.Setup(r => r.ListarDeActivosAsync(RanchoIdDePrueba)).ReturnsAsync(new List<Vacunacion>());
        _preneces.Setup(r => r.ListarAbiertasConPartoHastaAsync(RanchoIdDePrueba, It.IsAny<DateOnly>()))
            .ReturnsAsync(new List<Prenez>());
        _corrales.Setup(r => r.ListarAsync(RanchoIdDePrueba, false)).ReturnsAsync(new List<Corral>());
    }

    private TableroService CrearServicio()
    {
        var currentUser = new Mock<ICurrentUserContext>();
        currentUser.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        return new TableroService(_animales.Object, _vacunaciones.Object, _preneces.Object, _corrales.Object, currentUser.Object);
    }

    private static Animal Animal(string arete) => new() { Id = Guid.NewGuid(), Arete = arete };

    [Fact]
    public async Task SinRegistros_TodosLosIndicadoresEnCero()
    {
        var resumen = await CrearServicio().ObtenerResumenAsync();

        Assert.Equal(new TableroResumenResponse(0, 0, 0, 0, 0, 0, 0, 0), resumen);
    }

    [Fact]
    public async Task CuentaSoloAnimalesActivos_PorSexo()
    {
        // RN-04: vendidos y fallecidos no cuentan como activos.
        _animales.Setup(r => r.ContarPorEstadoYSexoAsync(RanchoIdDePrueba)).ReturnsAsync(new List<ConteoAnimales>
        {
            new(EstadoAnimal.Activo, SexoAnimal.Macho, 4),
            new(EstadoAnimal.Activo, SexoAnimal.Hembra, 6),
            new(EstadoAnimal.Vendido, SexoAnimal.Macho, 3),
            new(EstadoAnimal.Fallecido, SexoAnimal.Hembra, 2),
        });

        var resumen = await CrearServicio().ObtenerResumenAsync();

        Assert.Equal(10, resumen.AnimalesActivos);
        Assert.Equal(4, resumen.MachosActivos);
        Assert.Equal(6, resumen.HembrasActivas);
    }

    [Fact]
    public async Task Fallecidos_SeCuentanDesdeElPrimeroDeEnero()
    {
        var desdeEnero = new DateOnly(Hoy.Year, 1, 1);
        _animales.Setup(r => r.ContarFallecidosDesdeAsync(RanchoIdDePrueba, desdeEnero)).ReturnsAsync(2);

        var resumen = await CrearServicio().ObtenerResumenAsync();

        Assert.Equal(2, resumen.FallecidosDelAnio);
    }

    [Fact]
    public async Task Vacunados_UnAnimalConVariasVacunacionesCuentaUnaVez_YPendientesSegunRN09()
    {
        var a1 = Animal("T-01");
        var a2 = Animal("T-02");
        _vacunaciones.Setup(r => r.ListarDeActivosAsync(RanchoIdDePrueba)).ReturnsAsync(new List<Vacunacion>
        {
            Aplicada(a1, Hoy.AddMonths(-7), proxima: Hoy.AddDays(-2)),
            Aplicada(a1, Hoy.AddDays(-1)),
            Aplicada(a2, Hoy.AddDays(-30), proxima: Hoy.AddDays(3)),
        });

        var resumen = await CrearServicio().ObtenerResumenAsync();

        Assert.Equal(2, resumen.Vacunados);
        // a1 ya recibió de nuevo la vacuna; solo queda pendiente la de a2.
        Assert.Equal(1, resumen.VacunacionesPendientes);
    }

    [Fact]
    public async Task ProximasAParir_ConsultaLosProximos30Dias()
    {
        // RN-10: el repositorio recibe como tope hoy + 30 días.
        var hembra = Animal("T-03");
        _preneces.Setup(r => r.ListarAbiertasConPartoHastaAsync(RanchoIdDePrueba, Hoy.AddDays(30)))
            .ReturnsAsync(new List<Prenez>
            {
                new() { Id = Guid.NewGuid(), AnimalId = hembra.Id, Animal = hembra, FechaProbableParto = Hoy.AddDays(10) },
            });

        var resumen = await CrearServicio().ObtenerResumenAsync();

        Assert.Equal(1, resumen.ProximasAParir);
    }

    [Fact]
    public async Task CorralesActivos_NoIncluyeLosDesactivados()
    {
        _corrales.Setup(r => r.ListarAsync(RanchoIdDePrueba, false)).ReturnsAsync(new List<Corral>
        {
            new() { Id = Guid.NewGuid(), Nombre = "Norte", Capacidad = 10 },
            new() { Id = Guid.NewGuid(), Nombre = "Sur", Capacidad = 5 },
        });

        var resumen = await CrearServicio().ObtenerResumenAsync();

        Assert.Equal(2, resumen.CorralesActivos);
        _corrales.Verify(r => r.ListarAsync(RanchoIdDePrueba, true), Times.Never);
    }

    private static Vacunacion Aplicada(Animal animal, DateOnly aplicacion, DateOnly? proxima = null) =>
        new()
        {
            Id = Guid.NewGuid(),
            AnimalId = animal.Id,
            Animal = animal,
            VacunaId = Aftosa.Id,
            Vacuna = Aftosa,
            FechaAplicacion = aplicacion,
            FechaProximaDosis = proxima,
        };
}
