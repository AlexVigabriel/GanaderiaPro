using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-41: centro de notificaciones del usuario actual.
public class NotificacionServiceTests
{
    private static readonly Guid RanchoId = Guid.NewGuid();
    private static readonly Guid UsuarioId = Guid.NewGuid();

    private static Notificacion N(bool leida = false) => new()
    {
        Id = Guid.NewGuid(), RanchoId = RanchoId, UsuarioId = UsuarioId, Tipo = TipoNotificacion.CorralLleno,
        Mensaje = "El corral «Norte» está lleno (5/5).", ReferenciaTipo = "Corral", ReferenciaId = Guid.NewGuid(),
        Clave = Guid.NewGuid().ToString(), Leida = leida, Fecha = DateTime.UtcNow,
    };

    private static (NotificacionService Servicio, Mock<INotificacionRepository> Repo, Mock<IUnitOfWork> Uow) Crear()
    {
        var repo = new Mock<INotificacionRepository>();
        var usuario = new Mock<ICurrentUserContext>();
        usuario.Setup(u => u.RanchoId).Returns(RanchoId);
        usuario.Setup(u => u.UsuarioId).Returns(UsuarioId);
        var uow = new Mock<IUnitOfWork>();
        return (new NotificacionService(repo.Object, new Mock<IRevisorAlertas>().Object, usuario.Object, uow.Object), repo, uow);
    }

    [Fact]
    public async Task Listar_DevuelveLasDelUsuarioActualConSuReferencia()
    {
        var (servicio, repo, _) = Crear();
        var n = N();
        repo.Setup(r => r.ListarAsync(UsuarioId, NotificacionService.MaximoListado)).ReturnsAsync([n]);

        var lista = await servicio.ListarAsync();

        var r = Assert.Single(lista);
        Assert.Equal(n.Mensaje, r.Mensaje);
        Assert.Equal("Corral", r.ReferenciaTipo);
        Assert.Equal(n.ReferenciaId, r.ReferenciaId);
        Assert.False(r.Leida);
    }

    [Fact]
    public async Task MarcarLeida_LaMarcaYGuarda()
    {
        var (servicio, repo, uow) = Crear();
        var n = N();
        repo.Setup(r => r.ObtenerAsync(UsuarioId, n.Id)).ReturnsAsync(n);

        await servicio.MarcarLeidaAsync(n.Id);

        Assert.True(n.Leida);
        uow.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task MarcarLeida_DeOtroUsuario_NoSeEncuentra()
    {
        // El repositorio busca solo entre las del usuario actual.
        var (servicio, _, uow) = Crear();

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(() => servicio.MarcarLeidaAsync(Guid.NewGuid()));
        uow.Verify(u => u.GuardarCambiosAsync(), Times.Never);
    }

    [Fact]
    public async Task MarcarTodasLeidas_MarcaLasNoLeidasDelUsuario()
    {
        var (servicio, repo, uow) = Crear();
        var a = N();
        var b = N();
        repo.Setup(r => r.ListarNoLeidasAsync(UsuarioId)).ReturnsAsync([a, b]);

        await servicio.MarcarTodasLeidasAsync();

        Assert.True(a.Leida && b.Leida);
        uow.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task MarcarTodasLeidas_SinNoLeidas_NoGuardaNada()
    {
        var (servicio, repo, uow) = Crear();
        repo.Setup(r => r.ListarNoLeidasAsync(UsuarioId)).ReturnsAsync([]);

        await servicio.MarcarTodasLeidasAsync();

        uow.Verify(u => u.GuardarCambiosAsync(), Times.Never);
    }
}
