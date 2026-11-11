using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Planes;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-29 y HU-30: registrar socios y ver su listado.
public class SocioServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();

    private readonly Mock<IUsuarioRepository> _usuarioRepoMock = new();
    private readonly Mock<IInvitacionRepository> _invitacionRepoMock = new();
    private readonly Mock<IUnitOfWork> _unitOfWorkMock = new();
    private readonly List<Invitacion> _invitaciones = [];

    public SocioServiceTests()
    {
        _invitacionRepoMock.Setup(r => r.Agregar(It.IsAny<Invitacion>())).Callback<Invitacion>(_invitaciones.Add);
        _invitacionRepoMock.Setup(r => r.ListarSinUsarAsync(It.IsAny<Guid>()))
            .ReturnsAsync((Guid id) => _invitaciones.Where(i => i.UsuarioId == id && i.FechaUso == null).ToList());
        _invitacionRepoMock.Setup(r => r.VencimientosPendientesAsync(RanchoIdDePrueba)).ReturnsAsync(new Dictionary<Guid, DateTime>());
    }

    private SocioService CrearServicio(RolUsuario rolActual = RolUsuario.Propietario, IControlLimitesPlan? limites = null)
    {
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        currentUserMock.Setup(c => c.Rol).Returns(rolActual);
        return new SocioService(_usuarioRepoMock.Object, _invitacionRepoMock.Object, currentUserMock.Object,
            _unitOfWorkMock.Object, limites ?? SinLimites.Plan());
    }

    [Fact]
    public async Task Invitar_QuedaPendienteComoSocioConUnEnlace()
    {
        Usuario? guardado = null;
        _usuarioRepoMock.Setup(r => r.Agregar(It.IsAny<Usuario>())).Callback<Usuario>(u => guardado = u);

        var resultado = await CrearServicio().InvitarAsync(new InvitarSocioRequest(" Pedro Mamani ", " Pedro@Correo.com "));

        Assert.NotNull(guardado);
        Assert.Equal(RolUsuario.Socio, guardado!.Rol);
        Assert.Equal(EstadoUsuario.Pendiente, guardado.Estado);
        Assert.Equal("Pedro Mamani", guardado.Nombre);
        Assert.Equal("pedro@correo.com", guardado.Email);
        Assert.Equal(RanchoIdDePrueba, guardado.RanchoId);
        Assert.False(string.IsNullOrEmpty(resultado.Codigo));
        Assert.Single(_invitaciones);
        _unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task Invitar_ConCorreoYaRegistrado_SeRechaza()
    {
        // RN-02.
        _usuarioRepoMock.Setup(r => r.ExisteEmailAsync("ana@x.com")).ReturnsAsync(true);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => CrearServicio().InvitarAsync(new InvitarSocioRequest("Ana", "ana@x.com")));
        _usuarioRepoMock.Verify(r => r.Agregar(It.IsAny<Usuario>()), Times.Never);
    }

    [Theory]
    [InlineData("", "ana@x.com")]
    [InlineData("Ana", "no-es-correo")]
    public async Task Invitar_ConDatosInvalidos_SeRechaza(string nombre, string email)
    {
        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => CrearServicio().InvitarAsync(new InvitarSocioRequest(nombre, email)));
    }

    [Fact]
    public async Task Invitar_AlLimiteDeSociosDelPlan_SeBloquea()
    {
        // RN-11: el control del plan rechaza el alta.
        var limites = new Mock<IControlLimitesPlan>();
        limites.Setup(l => l.VerificarAsync(RecursoPlan.Socios, 1))
            .ThrowsAsync(new ReglaDeNegocioException("Llegaste al límite de 2 socios de tu plan Básico."));

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => CrearServicio(limites: limites.Object).InvitarAsync(new InvitarSocioRequest("Ana", "ana@x.com")));
        _usuarioRepoMock.Verify(r => r.Agregar(It.IsAny<Usuario>()), Times.Never);
    }

    [Fact]
    public async Task SoloElPropietarioGestionaSocios()
    {
        var service = CrearServicio(RolUsuario.Socio);

        await Assert.ThrowsAsync<AccesoDenegadoException>(() => service.ListarAsync());
        await Assert.ThrowsAsync<AccesoDenegadoException>(() => service.InvitarAsync(new InvitarSocioRequest("Ana", "ana@x.com")));
    }

    [Fact]
    public async Task Listar_DevuelveEstadoYUltimoAcceso()
    {
        var acceso = new DateTime(2026, 11, 1, 14, 30, 0, DateTimeKind.Utc);
        _usuarioRepoMock.Setup(r => r.ListarSociosAsync(RanchoIdDePrueba)).ReturnsAsync(new List<Usuario>
        {
            new() { Id = Guid.NewGuid(), Nombre = "Ana", Email = "ana@x.com", Rol = RolUsuario.Socio, Estado = EstadoUsuario.Activo, UltimoAcceso = acceso },
            new() { Id = Guid.NewGuid(), Nombre = "Beto", Email = "beto@x.com", Rol = RolUsuario.Socio, Estado = EstadoUsuario.Pendiente },
        });

        var socios = await CrearServicio().ListarAsync();

        Assert.Equal(2, socios.Count);
        Assert.Equal(EstadoUsuario.Activo, socios[0].Estado);
        Assert.Equal(acceso, socios[0].UltimoAcceso);
        Assert.Null(socios[1].UltimoAcceso);
    }

    [Fact]
    public async Task RegenerarInvitacion_DeUnColaborador_NoLoEncuentra()
    {
        // Por esta ruta solo se tocan socios.
        var vet = new Usuario { Id = Guid.NewGuid(), RanchoId = RanchoIdDePrueba, Rol = RolUsuario.Veterinario, Estado = EstadoUsuario.Pendiente };
        _usuarioRepoMock.Setup(r => r.ObtenerDelRanchoAsync(RanchoIdDePrueba, vet.Id)).ReturnsAsync(vet);

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(() => CrearServicio().RegenerarInvitacionAsync(vet.Id));
    }
}
