using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Eventos;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-40: alertas con el patrón Observer.
public class AlertasTests
{
    private static readonly Guid RanchoId = Guid.NewGuid();
    private static readonly DateOnly Hoy = FechaRancho.Hoy();

    private static Usuario U(string nombre, RolUsuario rol) =>
        new() { Id = Guid.NewGuid(), RanchoId = RanchoId, Nombre = nombre, Rol = rol, Estado = EstadoUsuario.Activo };

    // Notificador con un repositorio en memoria.
    private static (NotificadorAlertas Notificador, List<Notificacion> Guardadas) Notificador(params Usuario[] usuarios)
    {
        var guardadas = new List<Notificacion>();
        var repo = new Mock<INotificacionRepository>();
        repo.Setup(r => r.Agregar(It.IsAny<Notificacion>())).Callback<Notificacion>(guardadas.Add);
        repo.Setup(r => r.ExisteAsync(It.IsAny<Guid>(), It.IsAny<string>()))
            .ReturnsAsync((Guid u, string c) => guardadas.Any(n => n.UsuarioId == u && n.Clave == c));
        var usuariosRepo = new Mock<IUsuarioRepository>();
        usuariosRepo.Setup(r => r.ListarActivosAsync(RanchoId)).ReturnsAsync(usuarios);
        return (new NotificadorAlertas(repo.Object, usuariosRepo.Object, new Mock<IUnitOfWork>().Object), guardadas);
    }

    private static readonly VacunaPendienteDetectada Vacuna =
        new(RanchoId, Guid.NewGuid(), Guid.NewGuid(), "AR-001", "Fiebre aftosa", Hoy.AddDays(3));

    [Fact]
    public async Task VacunaPendiente_LlegaAlVeterinarioYAlPropietario()
    {
        var dueno = U("Ana", RolUsuario.Propietario);
        var vet = U("Dra. Rojas", RolUsuario.Veterinario);
        var (notificador, guardadas) = Notificador(dueno, vet, U("Beto", RolUsuario.EncargadoCorrales));

        await notificador.ManejarAsync(Vacuna);

        Assert.Equal(new[] { dueno.Id, vet.Id }.Order(), guardadas.Select(n => n.UsuarioId).Order());
        Assert.All(guardadas, n => Assert.Equal(TipoNotificacion.VacunaPendiente, n.Tipo));
        Assert.Contains("vence el", guardadas[0].Mensaje);
        Assert.Equal("Animal", guardadas[0].ReferenciaTipo);
    }

    [Fact]
    public async Task UnMismoHecho_SeNotificaUnaSolaVez()
    {
        var (notificador, guardadas) = Notificador(U("Ana", RolUsuario.Propietario), U("Dra. Rojas", RolUsuario.Veterinario));

        await notificador.ManejarAsync(Vacuna);
        await notificador.ManejarAsync(Vacuna);

        Assert.Equal(2, guardadas.Count);
    }

    [Fact]
    public async Task CorralLleno_LlegaAlEncargadoDeCorrales()
    {
        var encargado = U("Beto", RolUsuario.EncargadoCorrales);
        var (notificador, guardadas) = Notificador(U("Ana", RolUsuario.Propietario), encargado, U("Dra. Rojas", RolUsuario.Veterinario));

        await notificador.ManejarAsync(new CorralLleno(RanchoId, Guid.NewGuid(), "Corral Norte", 25));

        var n = Assert.Single(guardadas);
        Assert.Equal(encargado.Id, n.UsuarioId);
        Assert.Equal("El corral «Corral Norte» está lleno (25/25).", n.Mensaje);
    }

    [Fact]
    public async Task SinColaboradorConEseRol_ElResponsableEsElPropietario_RN12()
    {
        var dueno = U("Ana", RolUsuario.Propietario);
        var (notificador, guardadas) = Notificador(dueno, U("Iván", RolUsuario.EncargadoIngreso));

        await notificador.ManejarAsync(new PartoProximo(RanchoId, Guid.NewGuid(), Guid.NewGuid(), "AR-010", Hoy.AddDays(10)));

        Assert.Equal(dueno.Id, Assert.Single(guardadas).UsuarioId);
    }

    [Fact]
    public async Task PartoProximo_LlegaSoloAlVeterinario()
    {
        var vet = U("Dra. Rojas", RolUsuario.Veterinario);
        var (notificador, guardadas) = Notificador(U("Ana", RolUsuario.Propietario), vet);

        await notificador.ManejarAsync(new PartoProximo(RanchoId, Guid.NewGuid(), Guid.NewGuid(), "AR-010", Hoy.AddDays(10)));

        Assert.Equal(vet.Id, Assert.Single(guardadas).UsuarioId);
        Assert.Equal(TipoNotificacion.PartoProximo, guardadas[0].Tipo);
    }

    [Fact]
    public async Task ElPublicador_AvisaATodosLosObservadores()
    {
        var a = new Mock<IObservadorEventos>();
        var b = new Mock<IObservadorEventos>();
        var evento = new CorralLleno(RanchoId, Guid.NewGuid(), "C", 3);

        await new PublicadorEventos([a.Object, b.Object]).PublicarAsync(evento);

        a.Verify(o => o.ManejarAsync(evento), Times.Once);
        b.Verify(o => o.ManejarAsync(evento), Times.Once);
    }

    [Theory]
    [InlineData(2, true)]
    [InlineData(1, false)]
    public async Task AsignarElUltimoLugar_PublicaCorralLleno(int ocupados, bool publica)
    {
        var corral = new Corral { Id = Guid.NewGuid(), RanchoId = RanchoId, Nombre = "Corral Chico", Capacidad = 3, Activo = true };
        var animal = new Animal { Id = Guid.NewGuid(), RanchoId = RanchoId, Arete = "AR-050", Estado = EstadoAnimal.Activo };
        var corrales = new Mock<ICorralRepository>();
        corrales.Setup(r => r.ObtenerPorIdAsync(RanchoId, corral.Id)).ReturnsAsync(corral);
        corrales.Setup(r => r.ListarAnimalesActivosAsync(corral.Id))
            .ReturnsAsync(Enumerable.Range(0, ocupados).Select(_ => new Animal()).ToList());
        var animales = new Mock<IAnimalRepository>();
        animales.Setup(r => r.ObtenerPorIdAsync(RanchoId, animal.Id)).ReturnsAsync(animal);
        var usuario = new Mock<ICurrentUserContext>();
        usuario.Setup(u => u.RanchoId).Returns(RanchoId);
        var publicador = new Mock<IPublicadorEventos>();
        var servicio = new CorralService(corrales.Object, animales.Object, usuario.Object, new Mock<IUnitOfWork>().Object, publicador.Object);

        await servicio.AsignarAnimalAsync(animal.Id, corral.Id);

        publicador.Verify(p => p.PublicarAsync(It.Is<CorralLleno>(e => e.CorralId == corral.Id && e.Capacidad == 3)),
            publica ? Times.Once() : Times.Never());
    }

    [Fact]
    public async Task ElRevisor_PublicaVacunasDentroDe7DiasYPartosDentroDe15()
    {
        var animal = new Animal { Id = Guid.NewGuid(), RanchoId = RanchoId, Arete = "AR-001", Estado = EstadoAnimal.Activo };
        Vacunacion V(int diasHastaProxima) => new()
        {
            Id = Guid.NewGuid(), AnimalId = animal.Id, Animal = animal, VacunaId = Guid.NewGuid(),
            Vacuna = new Vacuna { Nombre = "Vacuna" }, FechaAplicacion = Hoy.AddDays(-30),
            FechaProximaDosis = Hoy.AddDays(diasHastaProxima),
        };
        var vacunas = new Mock<IVacunacionRepository>();
        vacunas.Setup(r => r.ListarDeActivosAsync(RanchoId)).ReturnsAsync([V(-2), V(7), V(8)]);
        var preneces = new Mock<IPrenezRepository>();
        var prenez = new Prenez { Id = Guid.NewGuid(), AnimalId = animal.Id, Animal = animal, FechaProbableParto = Hoy.AddDays(12) };
        preneces.Setup(r => r.ListarAbiertasConPartoHastaAsync(RanchoId, Hoy.AddDays(15))).ReturnsAsync([prenez]);
        var publicados = new List<IEventoRancho>();
        var publicador = new Mock<IPublicadorEventos>();
        publicador.Setup(p => p.PublicarAsync(It.IsAny<IEventoRancho>())).Callback<IEventoRancho>(publicados.Add);

        await new RevisorAlertas(vacunas.Object, preneces.Object, publicador.Object).RevisarAsync(RanchoId);

        Assert.Equal(2, publicados.OfType<VacunaPendienteDetectada>().Count());
        Assert.Equal(prenez.Id, Assert.Single(publicados.OfType<PartoProximo>()).PrenezId);
    }
}
