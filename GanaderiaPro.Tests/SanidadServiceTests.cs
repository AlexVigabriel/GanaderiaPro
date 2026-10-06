using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-27: indicadores (RN-09) y lista de pendientes.
public class SanidadServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();
    private static readonly DateOnly Hoy = FechaRancho.Hoy();
    private static readonly Vacuna Aftosa = new() { Id = Guid.NewGuid(), Nombre = "Fiebre aftosa" };
    private static readonly Vacuna Rabia = new() { Id = Guid.NewGuid(), Nombre = "Rabia bovina" };

    private readonly Mock<IVacunacionRepository> _repoMock = new();

    private SanidadService CrearServicio(params Vacunacion[] vacunaciones)
    {
        _repoMock.Setup(r => r.ListarDeActivosAsync(RanchoIdDePrueba)).ReturnsAsync(vacunaciones.ToList());
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        return new SanidadService(_repoMock.Object, currentUserMock.Object);
    }

    private static Animal Animal(string arete) => new() { Id = Guid.NewGuid(), Arete = arete };

    private static Vacunacion Aplicada(Animal animal, Vacuna vacuna, DateOnly aplicacion, DateOnly? proxima = null) =>
        new()
        {
            Id = Guid.NewGuid(),
            AnimalId = animal.Id,
            Animal = animal,
            VacunaId = vacuna.Id,
            Vacuna = vacuna,
            FechaAplicacion = aplicacion,
            FechaProximaDosis = proxima,
        };

    [Fact]
    public async Task Resumen_SinVacunaciones_TodoEnCero()
    {
        var service = CrearServicio();

        var resumen = await service.ObtenerResumenAsync();

        Assert.Equal(new SanidadResumenResponse(0, 0, 0), resumen);
        Assert.Empty(await service.ListarPendientesAsync());
    }

    [Fact]
    public async Task Resumen_CuentaAnimalesVacunadosUnaSolaVez()
    {
        // RN-09: un animal con dos vacunas cuenta como un vacunado.
        var a1 = Animal("S-01");
        var a2 = Animal("S-02");
        var service = CrearServicio(
            Aplicada(a1, Aftosa, Hoy.AddDays(-10)),
            Aplicada(a1, Rabia, Hoy.AddDays(-5)),
            Aplicada(a2, Aftosa, Hoy.AddDays(-3)));

        var resumen = await service.ObtenerResumenAsync();

        Assert.Equal(2, resumen.Vacunados);
    }

    [Fact]
    public async Task Pendientes_SoloCuentaLaUltimaAplicacionDeCadaVacuna()
    {
        // Aplicar de nuevo la vacuna cumple la dosis pendiente anterior.
        var animal = Animal("S-03");
        var service = CrearServicio(
            Aplicada(animal, Aftosa, Hoy.AddMonths(-7), proxima: Hoy.AddMonths(-1)),
            Aplicada(animal, Aftosa, Hoy.AddDays(-20)));

        var resumen = await service.ObtenerResumenAsync();

        Assert.Equal(0, resumen.Pendientes);
    }

    [Fact]
    public async Task Pendientes_OrdenadasPorProximaDosisYMarcaLasVencidas()
    {
        var a1 = Animal("S-04");
        var a2 = Animal("S-05");
        var a3 = Animal("S-06");
        var service = CrearServicio(
            Aplicada(a1, Aftosa, Hoy.AddMonths(-2), proxima: Hoy.AddDays(20)),
            Aplicada(a2, Rabia, Hoy.AddMonths(-12), proxima: Hoy.AddDays(-3)),
            Aplicada(a3, Aftosa, Hoy.AddMonths(-1), proxima: Hoy.AddDays(5)));

        var pendientes = await service.ListarPendientesAsync();
        var resumen = await service.ObtenerResumenAsync();

        Assert.Equal(new[] { "S-05", "S-06", "S-04" }, pendientes.Select(p => p.Arete));
        Assert.True(pendientes[0].Vencida);
        Assert.False(pendientes[1].Vencida);
        Assert.Equal(new SanidadResumenResponse(3, 3, 1), resumen);
    }
}
