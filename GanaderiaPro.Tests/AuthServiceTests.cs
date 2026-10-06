using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

public class AuthServiceTests
{
    private static AuthService CrearServicio(
        Mock<IUsuarioRepository> usuarioRepoMock,
        Mock<IRanchoRepository>? ranchoRepoMock = null,
        Mock<IPasswordHasher>? passwordHasherMock = null,
        Mock<ITokenGenerator>? tokenGeneratorMock = null)
    {
        ranchoRepoMock ??= new Mock<IRanchoRepository>();
        passwordHasherMock ??= new Mock<IPasswordHasher>();
        tokenGeneratorMock ??= new Mock<ITokenGenerator>();
        var unitOfWorkMock = new Mock<IUnitOfWork>();

        return new AuthService(
            usuarioRepoMock.Object,
            ranchoRepoMock.Object,
            passwordHasherMock.Object,
            tokenGeneratorMock.Object,
            unitOfWorkMock.Object);
    }

    private static RegistrarCuentaRequest RequestValido(string contrasena = "Clave123") =>
        new("Ana", "ana@ejemplo.com", contrasena, contrasena, "Rancho de Ana", PlanSuscripcion.Basico);

    [Fact]
    public async Task Registrar_ConCorreoYaRegistrado_LanzaExcepcion()
    {
        // RN-02: el correo es único en todo el sistema.
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ExisteEmailAsync("ana@ejemplo.com")).ReturnsAsync(true);
        var service = CrearServicio(usuarioRepoMock);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(RequestValido()));

        usuarioRepoMock.Verify(r => r.Agregar(It.IsAny<Usuario>()), Times.Never);
    }

    [Theory]
    [InlineData("corta1")] // menos de 8 caracteres
    [InlineData("sinnumeros")] // sin dígitos
    [InlineData("12345678")] // sin letras
    public async Task Registrar_ConContrasenaInvalida_LanzaExcepcion(string contrasenaInvalida)
    {
        // RN-03: mínimo 8 caracteres, con al menos una letra y un número.
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ExisteEmailAsync(It.IsAny<string>())).ReturnsAsync(false);
        var service = CrearServicio(usuarioRepoMock);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(RequestValido(contrasenaInvalida)));
    }

    [Fact]
    public async Task Registrar_ConContrasenasQueNoCoinciden_LanzaExcepcion()
    {
        // HU-08: la contraseña y su confirmación deben coincidir.
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ExisteEmailAsync(It.IsAny<string>())).ReturnsAsync(false);
        var service = CrearServicio(usuarioRepoMock);

        var request = new RegistrarCuentaRequest(
            "Ana", "ana@ejemplo.com", "Clave123", "Clave456", "Rancho de Ana", PlanSuscripcion.Basico);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));
    }

    [Fact]
    public async Task Registrar_ConDatosValidos_CreaRanchoConPruebaGratisDe10DiasYUsuarioPropietario()
    {
        // RN-15: la prueba gratuita dura 10 días desde el registro.
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ExisteEmailAsync(It.IsAny<string>())).ReturnsAsync(false);

        var ranchoRepoMock = new Mock<IRanchoRepository>();
        Rancho? ranchoGuardado = null;
        ranchoRepoMock.Setup(r => r.Agregar(It.IsAny<Rancho>())).Callback<Rancho>(r => ranchoGuardado = r);

        Usuario? usuarioGuardado = null;
        usuarioRepoMock.Setup(r => r.Agregar(It.IsAny<Usuario>())).Callback<Usuario>(u => usuarioGuardado = u);

        var passwordHasherMock = new Mock<IPasswordHasher>();
        passwordHasherMock.Setup(h => h.Hashear("Clave123")).Returns("hash-simulado");

        var service = CrearServicio(usuarioRepoMock, ranchoRepoMock, passwordHasherMock);

        var respuesta = await service.RegistrarAsync(RequestValido());

        Assert.NotNull(ranchoGuardado);
        Assert.NotNull(usuarioGuardado);
        Assert.Equal(
            ranchoGuardado!.FechaRegistro.AddDays(10),
            ranchoGuardado.FechaFinPruebaGratuita);
        Assert.Equal(RolUsuario.Propietario, usuarioGuardado!.Rol);
        Assert.Equal("hash-simulado", usuarioGuardado.PasswordHash);
        Assert.Contains("prueba gratuita", respuesta.Mensaje, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task IniciarSesion_ConCorreoInexistente_LanzaExcepcionConMensajeGenerico()
    {
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ObtenerPorEmailAsync(It.IsAny<string>())).ReturnsAsync((Usuario?)null);
        var service = CrearServicio(usuarioRepoMock);

        var excepcion = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.IniciarSesionAsync(new IniciarSesionRequest("nadie@ejemplo.com", "Clave123")));

        Assert.Equal("Correo o contraseña incorrectos.", excepcion.Message);
    }

    [Fact]
    public async Task IniciarSesion_ConContrasenaIncorrecta_LanzaExcepcionConElMismoMensajeGenerico()
    {
        // HU-09: el mensaje debe ser idéntico al de correo inexistente, para no
        // revelar cuál de los dos datos es el incorrecto.
        var usuario = new Usuario { Email = "ana@ejemplo.com", PasswordHash = "hash-guardado" };

        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ObtenerPorEmailAsync("ana@ejemplo.com")).ReturnsAsync(usuario);

        var passwordHasherMock = new Mock<IPasswordHasher>();
        passwordHasherMock.Setup(h => h.Verificar("hash-guardado", "ClaveIncorrecta1")).Returns(false);

        var service = CrearServicio(usuarioRepoMock, passwordHasherMock: passwordHasherMock);

        var excepcion = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.IniciarSesionAsync(new IniciarSesionRequest("ana@ejemplo.com", "ClaveIncorrecta1")));

        Assert.Equal("Correo o contraseña incorrectos.", excepcion.Message);
    }

    [Fact]
    public async Task IniciarSesion_ConCredencialesValidas_DevuelveToken()
    {
        var rancho = new Rancho { Nombre = "Rancho de Ana" };
        var usuario = new Usuario
        {
            Email = "ana@ejemplo.com",
            PasswordHash = "hash-guardado",
            Nombre = "Ana",
            Rancho = rancho,
        };

        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ObtenerPorEmailAsync("ana@ejemplo.com")).ReturnsAsync(usuario);

        var passwordHasherMock = new Mock<IPasswordHasher>();
        passwordHasherMock.Setup(h => h.Verificar("hash-guardado", "Clave123")).Returns(true);

        var tokenGeneratorMock = new Mock<ITokenGenerator>();
        tokenGeneratorMock.Setup(t => t.GenerarToken(usuario)).Returns("token-simulado");

        var service = CrearServicio(usuarioRepoMock, passwordHasherMock: passwordHasherMock, tokenGeneratorMock: tokenGeneratorMock);

        var respuesta = await service.IniciarSesionAsync(new IniciarSesionRequest("ana@ejemplo.com", "Clave123"));

        Assert.Equal("token-simulado", respuesta.Token);
        Assert.Equal("Rancho de Ana", respuesta.NombreRancho);
        Assert.Equal("Ana", respuesta.NombreUsuario);
    }

    [Fact]
    public async Task CerrarSesion_IncrementaLaVersionYElTokenAnteriorDejaDeServir()
    {
        // HU-52: el token viejo (versión 0) ya no es válido después de cerrar sesión.
        var usuario = new Usuario { Id = Guid.NewGuid(), Estado = EstadoUsuario.Activo, VersionSesion = 0 };
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ObtenerPorIdAsync(usuario.Id)).ReturnsAsync(usuario);
        var service = CrearServicio(usuarioRepoMock);

        Assert.True(await service.SesionVigenteAsync(usuario.Id, 0));

        await service.CerrarSesionAsync(usuario.Id);

        Assert.Equal(1, usuario.VersionSesion);
        Assert.False(await service.SesionVigenteAsync(usuario.Id, 0));
        Assert.True(await service.SesionVigenteAsync(usuario.Id, 1));
    }

    [Fact]
    public async Task SesionVigente_DeUsuarioInactivoOInexistente_EsFalso()
    {
        var inactivo = new Usuario { Id = Guid.NewGuid(), Estado = EstadoUsuario.Inactivo };
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ObtenerPorIdAsync(inactivo.Id)).ReturnsAsync(inactivo);
        var service = CrearServicio(usuarioRepoMock);

        Assert.False(await service.SesionVigenteAsync(inactivo.Id, 0));
        Assert.False(await service.SesionVigenteAsync(Guid.NewGuid(), 0));
    }

    [Theory]
    [InlineData(EstadoUsuario.Inactivo, "hash-guardado")]
    [InlineData(EstadoUsuario.Pendiente, "")]
    public async Task IniciarSesion_DesactivadoOSinAceptarLaInvitacion_MensajeGenerico(EstadoUsuario estado, string hash)
    {
        // HU-32: no entra quien fue desactivado ni quien no definió su contraseña.
        var usuario = new Usuario { Email = "vet@ejemplo.com", PasswordHash = hash, Estado = estado };
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ObtenerPorEmailAsync("vet@ejemplo.com")).ReturnsAsync(usuario);
        var passwordHasherMock = new Mock<IPasswordHasher>();
        passwordHasherMock.Setup(h => h.Verificar(It.IsAny<string>(), It.IsAny<string>())).Returns(true);
        var service = CrearServicio(usuarioRepoMock, passwordHasherMock: passwordHasherMock);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.IniciarSesionAsync(new IniciarSesionRequest("vet@ejemplo.com", "Clave123")));

        Assert.Equal("Correo o contraseña incorrectos.", ex.Message);
    }

    [Fact]
    public async Task IniciarSesion_PrimerIngresoDelColaborador_PasaAActivoYGuardaElAcceso()
    {
        var usuario = new Usuario
        {
            Email = "vet@ejemplo.com",
            PasswordHash = "hash-guardado",
            Rol = RolUsuario.Veterinario,
            Estado = EstadoUsuario.Pendiente,
        };
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ObtenerPorEmailAsync("vet@ejemplo.com")).ReturnsAsync(usuario);
        var passwordHasherMock = new Mock<IPasswordHasher>();
        passwordHasherMock.Setup(h => h.Verificar("hash-guardado", "Clave123")).Returns(true);
        var service = CrearServicio(usuarioRepoMock, passwordHasherMock: passwordHasherMock);

        // El correo se acepta escrito con mayúsculas (RN-02).
        await service.IniciarSesionAsync(new IniciarSesionRequest(" VET@Ejemplo.com ", "Clave123"));

        Assert.Equal(EstadoUsuario.Activo, usuario.Estado);
        Assert.NotNull(usuario.UltimoAcceso);
    }

    [Fact]
    public async Task Registrar_GuardaElCorreoEnMinusculas()
    {
        Usuario? guardado = null;
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ExisteEmailAsync("ana@ejemplo.com")).ReturnsAsync(false);
        usuarioRepoMock.Setup(r => r.Agregar(It.IsAny<Usuario>())).Callback<Usuario>(u => guardado = u);
        var service = CrearServicio(usuarioRepoMock);

        await service.RegistrarAsync(new RegistrarCuentaRequest("Ana", " Ana@Ejemplo.COM ", "Clave123", "Clave123", "Rancho", PlanSuscripcion.Basico));

        Assert.Equal("ana@ejemplo.com", guardado!.Email);
        Assert.Equal(EstadoUsuario.Activo, guardado.Estado);
    }
}

