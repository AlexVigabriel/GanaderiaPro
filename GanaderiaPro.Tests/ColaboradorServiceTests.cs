using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Planes;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-32: invitar colaboradores, aceptar la invitación y gestionar su acceso.
public class ColaboradorServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();

    private readonly Mock<IUsuarioRepository> _usuarioRepoMock = new();
    private readonly Mock<IInvitacionRepository> _invitacionRepoMock = new();
    private readonly Mock<IUnitOfWork> _unitOfWorkMock = new();
    private readonly List<Invitacion> _invitaciones = [];

    public ColaboradorServiceTests()
    {
        _invitacionRepoMock.Setup(r => r.Agregar(It.IsAny<Invitacion>())).Callback<Invitacion>(_invitaciones.Add);
        _invitacionRepoMock.Setup(r => r.ListarSinUsarAsync(It.IsAny<Guid>()))
            .ReturnsAsync((Guid id) => _invitaciones.Where(i => i.UsuarioId == id && i.FechaUso == null).ToList());
        _invitacionRepoMock.Setup(r => r.VencimientosPendientesAsync(RanchoIdDePrueba)).ReturnsAsync(new Dictionary<Guid, DateTime>());
    }

    private ColaboradorService CrearServicio(RolUsuario rolDelUsuarioActual = RolUsuario.Propietario)
    {
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        currentUserMock.Setup(c => c.Rol).Returns(rolDelUsuarioActual);
        return new ColaboradorService(_usuarioRepoMock.Object, _invitacionRepoMock.Object, currentUserMock.Object, _unitOfWorkMock.Object, SinLimites.Plan());
    }

    private Usuario Colaborador(EstadoUsuario estado, RolUsuario rol = RolUsuario.Veterinario, string passwordHash = "hash")
    {
        var u = new Usuario { Id = Guid.NewGuid(), RanchoId = RanchoIdDePrueba, Nombre = "Vet", Email = "vet@x.com", Rol = rol, Estado = estado, PasswordHash = passwordHash };
        _usuarioRepoMock.Setup(r => r.ObtenerDelRanchoAsync(RanchoIdDePrueba, u.Id)).ReturnsAsync(u);
        return u;
    }

    [Fact]
    public async Task Invitar_ConDatosValidos_QuedaPendienteConElRolYUnEnlaceDe7Dias()
    {
        Usuario? guardado = null;
        _usuarioRepoMock.Setup(r => r.Agregar(It.IsAny<Usuario>())).Callback<Usuario>(u => guardado = u);
        var service = CrearServicio();

        var resultado = await service.InvitarAsync(new InvitarColaboradorRequest(" Laura Rojas ", " Laura@Correo.com ", RolUsuario.Veterinario));

        Assert.NotNull(guardado);
        Assert.Equal(EstadoUsuario.Pendiente, guardado!.Estado);
        Assert.Equal(RolUsuario.Veterinario, guardado.Rol);
        Assert.Equal("laura@correo.com", guardado.Email);
        Assert.Equal(RanchoIdDePrueba, guardado.RanchoId);
        Assert.Empty(guardado.PasswordHash);
        Assert.False(string.IsNullOrEmpty(resultado.Codigo));
        // Solo se guarda el hash del código, nunca el código.
        Assert.Equal(CodigoInvitacion.Hash(resultado.Codigo), Assert.Single(_invitaciones).CodigoHash);
        Assert.InRange(resultado.Vence - DateTime.UtcNow, TimeSpan.FromDays(6.9), TimeSpan.FromDays(7));
    }

    [Fact]
    public async Task Invitar_ConCorreoYaRegistrado_LoRechaza()
    {
        // RN-02, sin distinguir mayúsculas.
        _usuarioRepoMock.Setup(r => r.ExisteEmailAsync("ana@correo.com")).ReturnsAsync(true);
        var service = CrearServicio();

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.InvitarAsync(new InvitarColaboradorRequest("Ana", "ANA@correo.com", RolUsuario.EncargadoIngreso)));

        Assert.Contains("correo", ex.Message);
        _usuarioRepoMock.Verify(r => r.Agregar(It.IsAny<Usuario>()), Times.Never);
    }

    [Theory]
    [InlineData(RolUsuario.Propietario)]
    [InlineData(RolUsuario.Socio)]
    public async Task Invitar_ConUnRolQueNoEsDeColaborador_LoRechaza(RolUsuario rol)
    {
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.InvitarAsync(new InvitarColaboradorRequest("Ana", "ana@x.com", rol)));
    }

    [Theory]
    [InlineData("sin-arroba.com")]
    [InlineData("ana@")]
    [InlineData("ana@correo")]
    public async Task Invitar_ConCorreoInvalido_LoRechaza(string email)
    {
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.InvitarAsync(new InvitarColaboradorRequest("Ana", email, RolUsuario.Veterinario)));
    }

    [Theory]
    [InlineData(RolUsuario.Veterinario)]
    [InlineData(RolUsuario.EncargadoCorrales)]
    [InlineData(RolUsuario.Socio)]
    public async Task SoloElPropietario_GestionaColaboradores(RolUsuario rol)
    {
        var service = CrearServicio(rol);

        await Assert.ThrowsAsync<AccesoDenegadoException>(() => service.ListarAsync());
        await Assert.ThrowsAsync<AccesoDenegadoException>(
            () => service.InvitarAsync(new InvitarColaboradorRequest("Ana", "ana@x.com", RolUsuario.Veterinario)));
    }

    [Fact]
    public async Task CambiarRol_CierraLasSesionesDelColaborador()
    {
        var colaborador = Colaborador(EstadoUsuario.Activo);
        var service = CrearServicio();

        var resultado = await service.CambiarRolAsync(colaborador.Id, new CambiarRolRequest(RolUsuario.EncargadoCorrales));

        Assert.Equal(RolUsuario.EncargadoCorrales, resultado.Rol);
        Assert.Equal(1, colaborador.VersionSesion);
    }

    [Fact]
    public async Task CambiarRol_DelPropietario_NoLoEncuentra()
    {
        // El propietario no es un colaborador: no se le cambia el rol.
        var propietario = Colaborador(EstadoUsuario.Activo, RolUsuario.Propietario);
        var service = CrearServicio();

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(
            () => service.CambiarRolAsync(propietario.Id, new CambiarRolRequest(RolUsuario.Veterinario)));
    }

    [Fact]
    public async Task Desactivar_QuitaElAccesoCierraSesionesEInvalidaElEnlace()
    {
        var colaborador = Colaborador(EstadoUsuario.Pendiente, passwordHash: "");
        _invitaciones.Add(new Invitacion { UsuarioId = colaborador.Id, FechaVencimiento = DateTime.UtcNow.AddDays(5) });
        var service = CrearServicio();

        var resultado = await service.CambiarEstadoAsync(colaborador.Id, activo: false);

        Assert.Equal(EstadoUsuario.Inactivo, resultado.Estado);
        Assert.Equal(1, colaborador.VersionSesion);
        Assert.False(_invitaciones[0].EstaVigente(DateTime.UtcNow));
    }

    [Theory]
    [InlineData("hash", EstadoUsuario.Activo)]
    [InlineData("", EstadoUsuario.Pendiente)]
    public async Task Activar_VuelveAActivoSiYaEntroOAPendienteSiNunca(string passwordHash, EstadoUsuario esperado)
    {
        var colaborador = Colaborador(EstadoUsuario.Inactivo, passwordHash: passwordHash);
        var service = CrearServicio();

        var resultado = await service.CambiarEstadoAsync(colaborador.Id, activo: true);

        Assert.Equal(esperado, resultado.Estado);
    }

    [Fact]
    public async Task RegenerarInvitacion_InvalidaLaAnterior()
    {
        var colaborador = Colaborador(EstadoUsuario.Pendiente, passwordHash: "");
        var anterior = new Invitacion { UsuarioId = colaborador.Id, FechaVencimiento = DateTime.UtcNow.AddDays(3) };
        _invitaciones.Add(anterior);
        var service = CrearServicio();

        var nueva = await service.RegenerarInvitacionAsync(colaborador.Id);

        Assert.False(anterior.EstaVigente(DateTime.UtcNow));
        Assert.Equal(2, _invitaciones.Count);
        Assert.Equal(CodigoInvitacion.Hash(nueva.Codigo), _invitaciones[1].CodigoHash);
    }

    [Fact]
    public async Task RegenerarInvitacion_DeUnColaboradorActivo_LoRechaza()
    {
        var colaborador = Colaborador(EstadoUsuario.Activo);
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegenerarInvitacionAsync(colaborador.Id));
    }
}

// HU-32: el colaborador acepta la invitación desde el enlace.
public class InvitacionServiceTests
{
    private readonly Mock<IInvitacionRepository> _repoMock = new();
    private readonly Mock<IPasswordHasher> _hasherMock = new();
    private readonly Mock<IUnitOfWork> _unitOfWorkMock = new();

    private InvitacionService CrearServicio() => new(_repoMock.Object, _hasherMock.Object, _unitOfWorkMock.Object);

    private Invitacion Invitacion(string codigo, DateTime vence, EstadoUsuario estado = EstadoUsuario.Pendiente, DateTime? usada = null)
    {
        var invitacion = new Invitacion
        {
            CodigoHash = CodigoInvitacion.Hash(codigo),
            FechaVencimiento = vence,
            FechaUso = usada,
            Usuario = new Usuario { Nombre = "Laura", Email = "laura@x.com", Rol = RolUsuario.Veterinario, Estado = estado, Rancho = new Rancho { Nombre = "La Esperanza" } },
        };
        _repoMock.Setup(r => r.ObtenerPorHashAsync(invitacion.CodigoHash)).ReturnsAsync(invitacion);
        return invitacion;
    }

    [Fact]
    public async Task Aceptar_GuardaLaContrasenaMarcaElEnlaceUsadoYSigueEnPendiente()
    {
        // Queda Pendiente hasta su primer inicio de sesión.
        var invitacion = Invitacion("abc", DateTime.UtcNow.AddDays(2));
        _hasherMock.Setup(h => h.Hashear("Clave1234")).Returns("hash-nuevo");
        var service = CrearServicio();

        await service.AceptarAsync("abc", new AceptarInvitacionRequest("Clave1234", "Clave1234"));

        Assert.Equal("hash-nuevo", invitacion.Usuario!.PasswordHash);
        Assert.NotNull(invitacion.FechaUso);
        Assert.Equal(EstadoUsuario.Pendiente, invitacion.Usuario.Estado);
    }

    [Fact]
    public async Task Obtener_MuestraElRanchoYElRol()
    {
        Invitacion("abc", DateTime.UtcNow.AddDays(2));
        var service = CrearServicio();

        var datos = await service.ObtenerAsync("abc");

        Assert.Equal(("La Esperanza", "Laura", RolUsuario.Veterinario), (datos.Rancho, datos.Nombre, datos.Rol));
    }

    [Fact]
    public async Task EnlaceVencidoUsadoInexistenteODesactivado_MismoMensaje()
    {
        Invitacion("vencido", DateTime.UtcNow.AddMinutes(-1));
        Invitacion("usado", DateTime.UtcNow.AddDays(1), usada: DateTime.UtcNow);
        Invitacion("desactivado", DateTime.UtcNow.AddDays(1), EstadoUsuario.Inactivo);
        var service = CrearServicio();

        var mensajes = new List<string>();
        foreach (var codigo in new[] { "vencido", "usado", "desactivado", "no-existe" })
        {
            mensajes.Add((await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.ObtenerAsync(codigo))).Message);
        }

        Assert.Single(mensajes.Distinct());
    }

    [Theory]
    [InlineData("corta1", "corta1")]
    [InlineData("sinnumeros", "sinnumeros")]
    [InlineData("Clave1234", "Otra12345")]
    public async Task Aceptar_ConContrasenaInvalidaONoCoincide_LoRechaza(string contrasena, string confirmacion)
    {
        // RN-03 y confirmación igual.
        var invitacion = Invitacion("abc", DateTime.UtcNow.AddDays(2));
        var service = CrearServicio();

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.AceptarAsync("abc", new AceptarInvitacionRequest(contrasena, confirmacion)));

        Assert.Null(invitacion.FechaUso);
    }
}
