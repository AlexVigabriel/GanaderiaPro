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

    // ---- RC-10: diagnóstico de preñez y aborto

    [Fact]
    public async Task Diagnostico_Confirmada_LaPrenezSigueAbierta()
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-60));
        var (servicio, _, uow) = Crear(vaca, abierta);

        var r = await servicio.RegistrarDiagnosticoAsync(vaca.Id, abierta.Id,
            new RegistrarDiagnosticoPrenezRequest(Hoy, DiagnosticoPrenez.Confirmada));

        Assert.True(r.Abierta);
        Assert.Equal(EstadoPrenez.Abierta, r.Estado);
        Assert.Equal(DiagnosticoPrenez.Confirmada, r.Diagnostico);
        Assert.Equal(Hoy, r.FechaDiagnostico);
        uow.Verify(x => x.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task Diagnostico_Vacia_CierraLaPrenez()
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-45));
        var (servicio, _, _) = Crear(vaca, abierta);

        var r = await servicio.RegistrarDiagnosticoAsync(vaca.Id, abierta.Id,
            new RegistrarDiagnosticoPrenezRequest(Hoy, DiagnosticoPrenez.Vacia));

        Assert.False(r.Abierta);
        Assert.Equal(EstadoPrenez.Vacia, r.Estado);
        Assert.Equal(Hoy, abierta.FechaCierre);
    }

    [Fact]
    public async Task Diagnostico_DosVeces_SeRechaza()
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-60));
        abierta.Diagnostico = DiagnosticoPrenez.Confirmada;
        abierta.FechaDiagnostico = Hoy.AddDays(-5);
        var (servicio, _, _) = Crear(vaca, abierta);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.RegistrarDiagnosticoAsync(vaca.Id, abierta.Id,
            new RegistrarDiagnosticoPrenezRequest(Hoy, DiagnosticoPrenez.Vacia)));

        Assert.Contains("ya tiene el diagnóstico", ex.Message);
    }

    [Theory]
    [InlineData(1, "futura")]
    [InlineData(-61, "anterior al servicio")]
    public async Task DiagnosticoYAborto_ConFechaFuturaOAntesDelServicio_SeRechazan(int dias, string mensaje)
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-60));
        var (servicio, _, _) = Crear(vaca, abierta);

        var exDiagnostico = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.RegistrarDiagnosticoAsync(
            vaca.Id, abierta.Id, new RegistrarDiagnosticoPrenezRequest(Hoy.AddDays(dias), DiagnosticoPrenez.Confirmada)));
        var exAborto = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAbortoAsync(vaca.Id, abierta.Id, new RegistrarAbortoRequest(Hoy.AddDays(dias))));

        Assert.Contains(mensaje, exDiagnostico.Message);
        Assert.Contains(mensaje, exAborto.Message);
    }

    [Fact]
    public async Task Aborto_CierraLaPrenez_YNoPuedeSerAnteriorAlDiagnostico()
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-90));
        abierta.Diagnostico = DiagnosticoPrenez.Confirmada;
        abierta.FechaDiagnostico = Hoy.AddDays(-30);
        var (servicio, _, _) = Crear(vaca, abierta);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAbortoAsync(vaca.Id, abierta.Id, new RegistrarAbortoRequest(Hoy.AddDays(-31))));

        var r = await servicio.RegistrarAbortoAsync(vaca.Id, abierta.Id, new RegistrarAbortoRequest(Hoy.AddDays(-2)));

        Assert.False(r.Abierta);
        Assert.Equal(EstadoPrenez.Aborto, r.Estado);
        Assert.Equal(Hoy.AddDays(-2), r.FechaAborto);
    }

    [Fact]
    public async Task Aborto_ConDiagnosticoPosteriorAlDia259_AvisaQueSeRegistraComoParto()
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-270));
        abierta.Diagnostico = DiagnosticoPrenez.Confirmada;
        abierta.FechaDiagnostico = Hoy;
        var (servicio, _, _) = Crear(vaca, abierta);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAbortoAsync(vaca.Id, abierta.Id, new RegistrarAbortoRequest(Hoy.AddDays(-11))));

        Assert.Contains("Ya no se puede registrar un aborto", ex.Message);
        Assert.Contains("parto", ex.Message);
    }

    [Fact]
    public async Task UnaPrenezCerradaConAborto_NoAdmiteParto()
    {
        var vaca = Vaca();
        var cerrada = Prenez(vaca, Hoy.AddDays(-90));
        cerrada.FechaAborto = Hoy.AddDays(-10);
        var (servicio, _, _) = Crear(vaca, cerrada);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarPartoAsync(vaca.Id, cerrada.Id, new RegistrarPartoRequest(Hoy)));

        Assert.Contains("aborto", ex.Message);
    }

    [Fact]
    public async Task TrasUnAborto_ElNuevoServicioEsperaUnCicloDeCelo()
    {
        var vaca = Vaca();
        var cerrada = Prenez(vaca, Hoy.AddDays(-120));
        cerrada.FechaAborto = Hoy.AddDays(-30);
        var (servicio, repo, _) = Crear(vaca, cerrada);

        // El mismo día del aborto, o a los 20 días, todavía no.
        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy.AddDays(-30))));
        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy.AddDays(-10))));
        Assert.Contains("ciclo de celo", ex.Message);

        var r = await servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy.AddDays(-9)));

        Assert.True(r.Abierta);
        repo.Verify(x => x.Agregar(It.IsAny<Prenez>()), Times.Once);
    }

    [Fact]
    public async Task TrasUnParto_ElNuevoServicioEspera40Dias()
    {
        var vaca = Vaca();
        var (servicio, _, _) = Crear(vaca, Prenez(vaca, Hoy.AddDays(-330), parto: Hoy.AddDays(-50)));

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy.AddDays(-11))));
        Assert.Contains("40 días", ex.Message);

        var r = await servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy.AddDays(-10)));
        Assert.True(r.Abierta);
    }

    [Fact]
    public async Task TrasUnDiagnosticoVacia_SePuedeServirDesdeEseDia()
    {
        var vaca = Vaca();
        var cerrada = Prenez(vaca, Hoy.AddDays(-40));
        cerrada.Diagnostico = DiagnosticoPrenez.Vacia;
        cerrada.FechaDiagnostico = Hoy.AddDays(-5);
        var (servicio, _, _) = Crear(vaca, cerrada);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy.AddDays(-6))));
        var r = await servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy.AddDays(-5)));
        Assert.True(r.Abierta);
    }

    [Fact]
    public async Task Diagnostico_AntesDeLos30DiasDelServicio_SeRechaza()
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-29));
        var (servicio, _, _) = Crear(vaca, abierta);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.RegistrarDiagnosticoAsync(vaca.Id, abierta.Id,
            new RegistrarDiagnosticoPrenezRequest(Hoy, DiagnosticoPrenez.Confirmada)));

        Assert.Contains("30 días", ex.Message);
    }

    [Fact]
    public async Task Diagnostico_ElMismoDiaDelServicio_SeRechaza()
    {
        // El caso de la prueba manual: servicio y «Confirmada» el mismo día.
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy);
        var (servicio, _, _) = Crear(vaca, abierta);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.RegistrarDiagnosticoAsync(vaca.Id, abierta.Id,
            new RegistrarDiagnosticoPrenezRequest(Hoy, DiagnosticoPrenez.Confirmada)));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(41)]
    public async Task Aborto_AntesDeLos42Dias_EsMuerteEmbrionaria(int diasDesdeServicio)
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-diasDesdeServicio));
        var (servicio, _, _) = Crear(vaca, abierta);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAbortoAsync(vaca.Id, abierta.Id, new RegistrarAbortoRequest(Hoy)));

        Assert.Contains("muerte embrionaria", ex.Message);
    }

    [Fact]
    public async Task Aborto_DesdeLos260Dias_SeRegistraComoParto()
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-260));
        var (servicio, _, _) = Crear(vaca, abierta);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAbortoAsync(vaca.Id, abierta.Id, new RegistrarAbortoRequest(Hoy)));
        Assert.Contains("parto", ex.Message);

        // El día 259 todavía es aborto.
        var r = await servicio.RegistrarAbortoAsync(vaca.Id, abierta.Id, new RegistrarAbortoRequest(Hoy.AddDays(-1)));
        Assert.Equal(EstadoPrenez.Aborto, r.Estado);
    }

    [Fact]
    public async Task Parto_AntesDeLos260Dias_SeRechaza()
    {
        var vaca = Vaca();
        var abierta = Prenez(vaca, Hoy.AddDays(-259));
        var (servicio, _, _) = Crear(vaca, abierta);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarPartoAsync(vaca.Id, abierta.Id, new RegistrarPartoRequest(Hoy)));

        Assert.Contains("260 días", ex.Message);
    }

    [Fact]
    public async Task DosAbortosElMismoDia_NoSonPosibles()
    {
        // El caso de la prueba manual: aborto, servicio nuevo y otro aborto el mismo día.
        var vaca = Vaca();
        var cerrada = Prenez(vaca, Hoy.AddDays(-100));
        cerrada.FechaAborto = Hoy;
        var (servicio, _, _) = Crear(vaca, cerrada);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarServicioAsync(vaca.Id, new RegistrarServicioRequest(Hoy)));
    }

    [Theory]
    [InlineData(null, null, null, true)]
    [InlineData(DiagnosticoPrenez.Confirmada, null, null, true)]
    [InlineData(DiagnosticoPrenez.Vacia, null, null, false)]
    [InlineData(null, -3, null, false)]
    [InlineData(null, null, -1, false)]
    public void Abierta_SoloSiNoHayParto_NiAborto_NiDiagnosticoVacia(
        DiagnosticoPrenez? diagnostico, int? abortoHaceDias, int? partoHaceDias, bool abierta)
    {
        // La misma regla usa la consulta de próximas a parir (tablero, alertas y asistente).
        var p = new Prenez
        {
            FechaServicio = Hoy.AddDays(-280),
            Diagnostico = diagnostico,
            FechaDiagnostico = diagnostico is null ? null : Hoy.AddDays(-200),
            FechaAborto = abortoHaceDias is { } a ? Hoy.AddDays(a) : null,
            FechaParto = partoHaceDias is { } d ? Hoy.AddDays(d) : null,
        };

        Assert.Equal(abierta, p.Abierta);
    }
}
