using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Planes;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-47: lo registrado sin conexión llega con el código del dispositivo
// (IdCliente). Si el envío se reintenta, no se duplica.
public class SincronizacionTests
{
    private static readonly Guid RanchoId = Guid.NewGuid();
    private static readonly DateOnly HaceDosAnios = FechaRancho.Hoy().AddYears(-2);

    private static (AnimalService Servicio, Mock<IAnimalRepository> Repo, Mock<IUnitOfWork> Uow) Crear(
        IControlLimitesPlan? limites = null)
    {
        var repo = new Mock<IAnimalRepository>();
        repo.Setup(r => r.ExisteAreteAsync(RanchoId, It.IsAny<string>(), null)).ReturnsAsync(false);
        var usuario = new Mock<ICurrentUserContext>();
        usuario.Setup(u => u.RanchoId).Returns(RanchoId);
        var uow = new Mock<IUnitOfWork>();
        return (new AnimalService(repo.Object, usuario.Object, uow.Object, limites ?? SinLimites.Plan()), repo, uow);
    }

    private static RegistrarAnimalRequest Fila(string arete, Guid? idCliente) =>
        new(arete, SexoAnimal.Hembra, "Nelore", null, FechaNacimiento: HaceDosAnios, IdCliente: idCliente);

    private static Animal YaGuardado(string arete, Guid idCliente) => new()
    {
        Id = Guid.NewGuid(),
        RanchoId = RanchoId,
        Arete = arete,
        Sexo = SexoAnimal.Hembra,
        Raza = "Nelore",
        FechaNacimiento = HaceDosAnios,
        IdCliente = idCliente,
    };

    [Fact]
    public async Task RegistrarLote_GuardaElCodigoDelDispositivo()
    {
        var (servicio, repo, _) = Crear();
        var idCliente = Guid.NewGuid();
        Animal? agregado = null;
        repo.Setup(r => r.Agregar(It.IsAny<Animal>())).Callback<Animal>(a => agregado = a);

        await servicio.RegistrarLoteAsync([Fila("OFF-001", idCliente)]);

        Assert.Equal(idCliente, agregado?.IdCliente);
    }

    [Fact]
    public async Task RegistrarLote_UnReintentoNoDuplicaYSeInformaComoRegistrado()
    {
        // El primer envío llegó, pero la respuesta se perdió: la app reintenta.
        var (servicio, repo, uow) = Crear();
        var idCliente = Guid.NewGuid();
        var existente = YaGuardado("OFF-001", idCliente);
        repo.Setup(r => r.ObtenerPorIdClienteAsync(RanchoId, idCliente)).ReturnsAsync(existente);
        // El arete ya existe… porque es el mismo animal: no debe contar como RN-01.
        repo.Setup(r => r.ExisteAreteAsync(RanchoId, "OFF-001", null)).ReturnsAsync(true);

        var resultado = await servicio.RegistrarLoteAsync([Fila("OFF-001", idCliente)]);

        Assert.Equal(existente.Id, Assert.Single(resultado.Registrados).Id);
        Assert.Empty(resultado.Rechazados);
        repo.Verify(r => r.Agregar(It.IsAny<Animal>()), Times.Never);
        uow.Verify(u => u.GuardarCambiosAsync(), Times.Never);
    }

    [Fact]
    public async Task RegistrarLote_MismoAreteConOtroCodigo_EsConflictoRN01()
    {
        var (servicio, repo, _) = Crear();
        repo.Setup(r => r.ExisteAreteAsync(RanchoId, "AR-001", null)).ReturnsAsync(true);

        var resultado = await servicio.RegistrarLoteAsync([Fila("AR-001", Guid.NewGuid())]);

        Assert.Empty(resultado.Registrados);
        var rechazo = Assert.Single(resultado.Rechazados);
        Assert.Equal(1, rechazo.Fila);
        Assert.Contains("Ya existe un animal con la identificación 'AR-001'", rechazo.Motivo);
    }

    [Fact]
    public async Task RegistrarLote_LosReintentosNoOcupanLugarDelPlan()
    {
        // RN-11: queda 1 lugar. El reintento ya estaba contado; el nuevo entra.
        var limites = new Mock<IControlLimitesPlan>();
        limites.Setup(l => l.LugaresLibresAsync(RecursoPlan.Animales)).ReturnsAsync(1);
        limites.Setup(l => l.MensajeLimiteAsync(RecursoPlan.Animales)).ReturnsAsync("Plan lleno");
        var (servicio, repo, _) = Crear(limites.Object);
        var reintento = Guid.NewGuid();
        repo.Setup(r => r.ObtenerPorIdClienteAsync(RanchoId, reintento)).ReturnsAsync(YaGuardado("OFF-001", reintento));

        var resultado = await servicio.RegistrarLoteAsync(
            [Fila("OFF-001", reintento), Fila("OFF-002", Guid.NewGuid()), Fila("OFF-003", Guid.NewGuid())]);

        Assert.Equal(new[] { "OFF-002", "OFF-001" }, resultado.Registrados.Select(a => a.Arete));
        var rechazo = Assert.Single(resultado.Rechazados);
        Assert.Equal(3, rechazo.Fila);
        Assert.Equal("Plan lleno", rechazo.Motivo);
    }

    [Fact]
    public async Task Registrar_UnReintentoDevuelveElYaCreado()
    {
        var (servicio, repo, uow) = Crear();
        var idCliente = Guid.NewGuid();
        var existente = YaGuardado("OFF-001", idCliente);
        repo.Setup(r => r.ObtenerPorIdClienteAsync(RanchoId, idCliente)).ReturnsAsync(existente);

        var respuesta = await servicio.RegistrarAsync(Fila("OFF-001", idCliente));

        Assert.Equal(existente.Id, respuesta.Id);
        repo.Verify(r => r.Agregar(It.IsAny<Animal>()), Times.Never);
        uow.Verify(u => u.GuardarCambiosAsync(), Times.Never);
    }
}
