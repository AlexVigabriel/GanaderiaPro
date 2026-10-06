using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Permisos;
using GanaderiaPro.Domain.Planes;
using GanaderiaPro.Infrastructure.Planes;
using Microsoft.Extensions.Configuration;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-58 / RN-11: una estrategia por plan.
public class EstrategiasPlanTests
{
    [Theory]
    [InlineData(PlanSuscripcion.Basico, RecursoPlan.Animales, 100)]
    [InlineData(PlanSuscripcion.Basico, RecursoPlan.Colaboradores, 3)]
    [InlineData(PlanSuscripcion.Basico, RecursoPlan.Socios, 2)]
    [InlineData(PlanSuscripcion.Intermedio, RecursoPlan.Animales, 200)]
    [InlineData(PlanSuscripcion.Intermedio, RecursoPlan.Colaboradores, 5)]
    [InlineData(PlanSuscripcion.Intermedio, RecursoPlan.Socios, 4)]
    public void Limites_SegunRN11(PlanSuscripcion plan, RecursoPlan recurso, int esperado)
    {
        Assert.Equal(esperado, EstrategiasPlan.Para(plan).Limite(recurso));
    }

    [Fact]
    public void PlanSuperior_SinLimiteHastaQueElPOLoDefina()
    {
        var superior = EstrategiasPlan.Para(PlanSuscripcion.Superior);

        Assert.All(Enum.GetValues<RecursoPlan>(), r => Assert.Null(superior.Limite(r)));
        Assert.Null(superior.PlanSiguiente);
    }

    [Fact]
    public void Configuracion_SoloLaVeElPropietario()
    {
        Assert.Equal(NivelAcceso.Escritura, MatrizPermisos.Acceso(RolUsuario.Propietario, Modulo.Configuracion));
        Assert.Equal(NivelAcceso.Ninguno, MatrizPermisos.Acceso(RolUsuario.Veterinario, Modulo.Configuracion));
        Assert.Equal(NivelAcceso.Ninguno, MatrizPermisos.Acceso(RolUsuario.EncargadoIngreso, Modulo.Configuracion));
    }

    [Fact]
    public void LimitesDePrueba_SoloCambianLoIndicadoEnLaConfiguracion()
    {
        var configuracion = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["LimitesPlanPrueba:Basico:Animales"] = "5" })
            .Build();
        var provider = new LimitesPlanProvider(configuracion);

        var basico = provider.Para(PlanSuscripcion.Basico);

        Assert.Equal(5, basico.Limite(RecursoPlan.Animales));
        Assert.Equal(3, basico.Limite(RecursoPlan.Colaboradores));
        Assert.Equal(200, provider.Para(PlanSuscripcion.Intermedio).Limite(RecursoPlan.Animales));
    }

    [Fact]
    public void SinConfiguracionDePrueba_ValenLosLimitesReales()
    {
        var provider = new LimitesPlanProvider(new ConfigurationBuilder().Build());

        Assert.Equal(100, provider.Para(PlanSuscripcion.Basico).Limite(RecursoPlan.Animales));
    }
}

// HU-58: el control único de límites.
public class ControlLimitesPlanTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();

    private readonly Mock<IAnimalRepository> _animalRepoMock = new();
    private readonly Mock<IUsuarioRepository> _usuarioRepoMock = new();

    private ControlLimitesPlan CrearControl(PlanSuscripcion plan, int animalesActivos, int colaboradores = 0, RolUsuario rol = RolUsuario.Propietario)
    {
        var ranchoRepoMock = new Mock<IRanchoRepository>();
        ranchoRepoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba)).ReturnsAsync(new Rancho { Id = RanchoIdDePrueba, Plan = plan });
        _animalRepoMock.Setup(r => r.ContarActivosAsync(RanchoIdDePrueba)).ReturnsAsync(animalesActivos);
        _usuarioRepoMock.Setup(r => r.ContarQueOcupanLugarAsync(RanchoIdDePrueba, It.Is<IReadOnlyCollection<RolUsuario>>(roles => roles.Contains(RolUsuario.Veterinario))))
            .ReturnsAsync(colaboradores);
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        currentUserMock.Setup(c => c.Rol).Returns(rol);
        return new ControlLimitesPlan(
            ranchoRepoMock.Object, _animalRepoMock.Object, _usuarioRepoMock.Object, new LimitesPlanProvider(new ConfigurationBuilder().Build()), currentUserMock.Object);
    }

    [Fact]
    public async Task Basico_Con100Activos_BloqueaEIndicaElLimiteYElPlan()
    {
        var control = CrearControl(PlanSuscripcion.Basico, animalesActivos: 100);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => control.VerificarAsync(RecursoPlan.Animales));

        Assert.Equal(
            "Tu plan Básico permite hasta 100 animales activos y ya llegaste al límite. Para sumar más, pasate al plan Intermedio.",
            ex.Message);
    }

    [Fact]
    public async Task Basico_Con99Activos_DejaRegistrarUnoMas()
    {
        var control = CrearControl(PlanSuscripcion.Basico, animalesActivos: 99);

        await control.VerificarAsync(RecursoPlan.Animales);
        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => control.VerificarAsync(RecursoPlan.Animales, cantidad: 2));
    }

    [Fact]
    public async Task OtroRol_RecibeElMensajeDeAvisarAlPropietario()
    {
        var control = CrearControl(PlanSuscripcion.Basico, animalesActivos: 100, rol: RolUsuario.EncargadoIngreso);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => control.VerificarAsync(RecursoPlan.Animales));

        Assert.Contains("Avisale al propietario", ex.Message);
    }

    [Fact]
    public async Task Superior_NuncaBloquea()
    {
        var control = CrearControl(PlanSuscripcion.Superior, animalesActivos: 5000);

        await control.VerificarAsync(RecursoPlan.Animales);
        Assert.Null(await control.LugaresLibresAsync(RecursoPlan.Animales));
    }

    [Fact]
    public async Task Uso_AvisaDesdeEl90PorCiento()
    {
        // RN-04: el repositorio cuenta solo los activos; las bajas no ocupan lugar.
        var control = CrearControl(PlanSuscripcion.Basico, animalesActivos: 90, colaboradores: 1);

        var uso = await control.ObtenerUsoAsync();
        var animales = uso.Recursos.Single(r => r.Recurso == RecursoPlan.Animales);
        var colaboradores = uso.Recursos.Single(r => r.Recurso == RecursoPlan.Colaboradores);

        Assert.Equal(("Básico", "Intermedio"), (uso.NombrePlan, uso.PlanSiguiente));
        Assert.Equal((90, 100, 90, true, false), (animales.Usados, animales.Limite, animales.Porcentaje, animales.CercaDelLimite, animales.Lleno));
        Assert.Equal((1, 3, false), (colaboradores.Usados, colaboradores.Limite, colaboradores.CercaDelLimite));
    }

    [Fact]
    public async Task Uso_Con89PorCiento_NoAvisa()
    {
        var control = CrearControl(PlanSuscripcion.Basico, animalesActivos: 89);

        var uso = await control.ObtenerUsoAsync();

        Assert.False(uso.Recursos.Single(r => r.Recurso == RecursoPlan.Animales).CercaDelLimite);
    }
}

// HU-58: los puntos de alta usan el control de límites.
public class PuntosDeAltaConLimiteTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();
    private static readonly DateOnly Nacimiento = FechaRancho.Hoy().AddYears(-2);

    private static Mock<ICurrentUserContext> UsuarioActual()
    {
        var mock = new Mock<ICurrentUserContext>();
        mock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        mock.Setup(c => c.Rol).Returns(RolUsuario.Propietario);
        return mock;
    }

    private static Mock<IControlLimitesPlan> ConLugares(int? libres, RecursoPlan recurso = RecursoPlan.Animales)
    {
        var mock = new Mock<IControlLimitesPlan>();
        mock.Setup(c => c.LugaresLibresAsync(recurso)).ReturnsAsync(libres);
        mock.Setup(c => c.MensajeLimiteAsync(recurso)).ReturnsAsync("Límite del plan.");
        if (libres is not null)
        {
            mock.Setup(c => c.VerificarAsync(recurso, It.Is<int>(n => n > libres)))
                .ThrowsAsync(new ReglaDeNegocioException("Límite del plan."));
        }

        return mock;
    }

    [Fact]
    public async Task CargaMultiple_RegistraHastaElLimiteYRechazaElResto()
    {
        var repoMock = new Mock<IAnimalRepository>();
        var service = new AnimalService(repoMock.Object, UsuarioActual().Object, new Mock<IUnitOfWork>().Object, ConLugares(2).Object);
        var filas = Enumerable.Range(1, 4)
            .Select(i => new RegistrarAnimalRequest($"L-{i}", SexoAnimal.Hembra, "Nelore", null, FechaNacimiento: Nacimiento))
            .ToList();

        var resultado = await service.RegistrarLoteAsync(filas);

        Assert.Equal(new[] { "L-1", "L-2" }, resultado.Registrados.Select(a => a.Arete));
        Assert.Equal(new[] { 3, 4 }, resultado.Rechazados.Select(r => r.Fila));
        Assert.All(resultado.Rechazados, r => Assert.Equal("Límite del plan.", r.Motivo));
    }

    [Fact]
    public async Task RegistrarUno_EnElLimite_LoBloquea()
    {
        var repoMock = new Mock<IAnimalRepository>();
        var service = new AnimalService(repoMock.Object, UsuarioActual().Object, new Mock<IUnitOfWork>().Object, ConLugares(0).Object);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.RegistrarAsync(new RegistrarAnimalRequest("L-9", SexoAnimal.Macho, "Gyr", null, FechaNacimiento: Nacimiento)));
        repoMock.Verify(r => r.Agregar(It.IsAny<Animal>()), Times.Never);
    }

    [Fact]
    public async Task VolverAActivoUnAnimalVendido_EnElLimite_LoBloquea()
    {
        // Si no, reactivar bajas sería una forma de pasar el límite.
        var vendido = new Animal { Id = Guid.NewGuid(), RanchoId = RanchoIdDePrueba, Arete = "L-10", Estado = EstadoAnimal.Vendido };
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, vendido.Id)).ReturnsAsync(vendido);
        var service = new AnimalService(repoMock.Object, UsuarioActual().Object, new Mock<IUnitOfWork>().Object, ConLugares(0).Object);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.CambiarEstadoAsync(vendido.Id, new CambiarEstadoRequest(EstadoAnimal.Activo)));
        Assert.Equal(EstadoAnimal.Vendido, vendido.Estado);
    }

    [Fact]
    public async Task InvitarColaborador_EnElLimite_LoBloquea()
    {
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        var service = new ColaboradorService(
            usuarioRepoMock.Object, new Mock<IInvitacionRepository>().Object, UsuarioActual().Object, new Mock<IUnitOfWork>().Object,
            ConLugares(0, RecursoPlan.Colaboradores).Object);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => service.InvitarAsync(new InvitarColaboradorRequest("Ana", "ana@x.com", RolUsuario.Veterinario)));
        usuarioRepoMock.Verify(r => r.Agregar(It.IsAny<Usuario>()), Times.Never);
    }

    [Fact]
    public async Task ReactivarColaborador_EnElLimite_LoBloquea()
    {
        var inactivo = new Usuario { Id = Guid.NewGuid(), RanchoId = RanchoIdDePrueba, Rol = RolUsuario.Veterinario, Estado = EstadoUsuario.Inactivo, PasswordHash = "h" };
        var usuarioRepoMock = new Mock<IUsuarioRepository>();
        usuarioRepoMock.Setup(r => r.ObtenerDelRanchoAsync(RanchoIdDePrueba, inactivo.Id)).ReturnsAsync(inactivo);
        var service = new ColaboradorService(
            usuarioRepoMock.Object, new Mock<IInvitacionRepository>().Object, UsuarioActual().Object, new Mock<IUnitOfWork>().Object,
            ConLugares(0, RecursoPlan.Colaboradores).Object);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.CambiarEstadoAsync(inactivo.Id, activo: true));
        Assert.Equal(EstadoUsuario.Inactivo, inactivo.Estado);
    }
}
