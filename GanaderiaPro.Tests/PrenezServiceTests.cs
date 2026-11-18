using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-56: preñez y parto (RN-10).
public class PrenezServiceTests
{
    private static readonly Guid RanchoId = Guid.NewGuid();
    private static readonly DateOnly Hoy = FechaRancho.Hoy();

    private static Animal Vaca(SexoAnimal sexo = SexoAnimal.Hembra, EstadoAnimal estado = EstadoAnimal.Activo) => new()
    {
        Id = Guid.NewGuid(),
        RanchoId = RanchoId,
        Arete = "AR-010",
        Nombre = "Rita",
        Sexo = sexo,
        Raza = "Nelore",
        Estado = estado,
        FechaNacimiento = Hoy.AddYears(-4),
    };

    private static (PrenezService Servicio, Mock<IPrenezRepository> Repo, Mock<IUnitOfWork> Uow) Crear(
        Animal animal, params Prenez[] anteriores)
    {
        var animales = new Mock<IAnimalRepository>();
        animales.Setup(r => r.ObtenerPorIdAsync(RanchoId, animal.Id)).ReturnsAsync(animal);
        var repo = new Mock<IPrenezRepository>();
        repo.Setup(r => r.ListarPorAnimalAsync(animal.Id)).ReturnsAsync(anteriores);
        foreach (var p in anteriores)
        {
            repo.Setup(r => r.ObtenerPorIdAsync(animal.Id, p.Id)).ReturnsAsync(p);
        }
        var usuario = new Mock<ICurrentUserContext>();
        usuario.Setup(u => u.RanchoId).Returns(RanchoId);
        var uow = new Mock<IUnitOfWork>();
        return (new PrenezService(repo.Object, animales.Object, usuario.Object, uow.Object), repo, uow);
    }

    private static Prenez Prenez(Animal animal, DateOnly servicio, DateOnly? parto = null) => new()
    {
        Id = Guid.NewGuid(),
        AnimalId = animal.Id,
        Animal = animal,
        FechaServicio = servicio,
        FechaProbableParto = Domain.Entities.Prenez.CalcularFechaProbableParto(servicio),
        FechaParto = parto,
    };

    [Fact]
    public async Task RegistrarServicio_CalculaElPartoProbableConRN10()
    {
        var vaca = Vaca();
        var (servicio, repo, uow) = Crear(vaca);
        var fecha = Hoy.AddDays(-10);

        var r = await servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(fecha));

        Assert.Equal(fecha.AddDays(283), r.FechaProbableParto);
        Assert.True(r.Abierta);
        repo.Verify(x => x.Agregar(It.Is<Prenez>(p => p.AnimalId == vaca.Id)), Times.Once);
        uow.Verify(x => x.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task RegistrarServicio_EnUnMacho_SeRechaza()
    {
        var toro = Vaca(SexoAnimal.Macho);
        var (servicio, repo, _) = Crear(toro);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(toro.Id, new RegistrarServicioRequest(Hoy)));

        Assert.Contains("hembra", ex.Message);
        repo.Verify(x => x.Agregar(It.IsAny<Prenez>()), Times.Never);
    }

    [Fact]
    public async Task RegistrarServicio_EnUnAnimalDadoDeBaja_SeRechaza()
    {
        var vendida = Vaca(estado: EstadoAnimal.Vendido);
        var (servicio, _, _) = Crear(vendida);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(vendida.Id, new RegistrarServicioRequest(Hoy)));
    }

    [Fact]
    public async Task RegistrarServicio_ConFechaFutura_SeRechaza()
    {
        var vaca = Vaca();
        var (servicio, _, _) = Crear(vaca);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy.AddDays(1))));

        Assert.Contains("futura", ex.Message);
    }

    [Fact]
    public async Task RegistrarServicio_AnteriorAlNacimiento_SeRechaza()
    {
        var vaca = Vaca();
        var (servicio, _, _) = Crear(vaca);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(vaca.FechaNacimiento!.Value.AddDays(-1))));
    }

    [Fact]
    public async Task RegistrarServicio_ConUnaPrenezAbierta_SeRechaza()
    {
        var vaca = Vaca();
        var (servicio, repo, _) = Crear(vaca, Prenez(vaca, Hoy.AddDays(-60)));

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy)));

        Assert.Contains("preñez abierta", ex.Message);
        repo.Verify(x => x.Agregar(It.IsAny<Prenez>()), Times.Never);
    }

    [Fact]
    public async Task RegistrarServicio_AnteriorAlUltimoParto_SeRechaza()
    {
        var vaca = Vaca();
        var (servicio, _, _) = Crear(vaca, Prenez(vaca, Hoy.AddDays(-400), parto: Hoy.AddDays(-110)));

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy.AddDays(-120))));
    }

    [Fact]
    public async Task RegistrarParto_CierraLaPrenez()
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-280));
        var (servicio, _, uow) = Crear(vaca, abierta);

        var r = await servicio.RegistrarPartoAsync(vaca.Id, abierta.Id, new RegistrarPartoRequest(Hoy));

        Assert.False(r.Abierta);
        Assert.Equal(Hoy, r.FechaParto);
        uow.Verify(x => x.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task RegistrarParto_DosVeces_SeRechaza()
    {
        var vaca = Vaca();
        var cerrada = Prenez(vaca, Hoy.AddDays(-300), parto: Hoy.AddDays(-5));
        var (servicio, _, _) = Crear(vaca, cerrada);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarPartoAsync(vaca.Id, cerrada.Id, new RegistrarPartoRequest(Hoy)));
    }

    [Fact]
    public async Task RegistrarParto_AnteriorAlServicio_SeRechaza()
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-10));
        var (servicio, _, _) = Crear(vaca, abierta);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarPartoAsync(vaca.Id, abierta.Id, new RegistrarPartoRequest(Hoy.AddDays(-11))));
    }

    [Fact]
    public async Task UnAnimalDeOtroRancho_NoSeEncuentra()
    {
        // RN-16: el repositorio solo devuelve animales del rancho actual.
        var (servicio, _, _) = Crear(Vaca());

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(
            () => servicio.RegistrarServicioAsync(Guid.NewGuid(), new RegistrarServicioRequest(Hoy)));
    }

    [Fact]
    public async Task ProximasAParir_CalculaLosDiasRestantes()
    {
        var vaca = Vaca();
        var prenez = Prenez(vaca, Hoy.AddDays(-270));
        var (servicio, repo, _) = Crear(vaca);
        repo.Setup(r => r.ListarAbiertasConPartoHastaAsync(RanchoId, Hoy.AddDays(30))).ReturnsAsync([prenez]);

        var lista = await servicio.ListarProximasAParirAsync();

        var proxima = Assert.Single(lista);
        Assert.Equal("AR-010", proxima.Arete);
        Assert.Equal(13, proxima.DiasRestantes);
    }
}
