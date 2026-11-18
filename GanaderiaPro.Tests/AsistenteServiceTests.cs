using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Eventos;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-36.1 y HU-38: asistente de consultas con catálogo predefinido.
public class AsistenteServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();

    private readonly Mock<IAnimalRepository> _animales = new();
    private readonly Mock<ICorralRepository> _corrales = new();
    private readonly Mock<IVacunacionRepository> _vacunaciones = new();
    private readonly Mock<IPrenezRepository> _preneces = new();
    private readonly Mock<IUsuarioRepository> _usuarios = new();
    private readonly Mock<IPublicadorEventos> _publicador = new();
    private readonly List<IEventoRancho> _publicados = [];

    private readonly Corral _norte = new() { Id = Guid.NewGuid(), Nombre = "Norte", Capacidad = 10, Activo = true };
    private readonly Corral _tres = new() { Id = Guid.NewGuid(), Nombre = "Corral 3", Capacidad = 10, Activo = true };
    private readonly List<Animal> _activos = [];
    private readonly List<Animal> _vendidos = [];

    public AsistenteServiceTests()
    {
        _animales.Setup(r => r.BuscarAsync(RanchoIdDePrueba, null, It.IsAny<EstadoAnimal>(), It.IsAny<SexoAnimal?>(), null))
            .ReturnsAsync((Guid _, string? _, EstadoAnimal estado, SexoAnimal? sexo, string? _) =>
                (estado == EstadoAnimal.Activo ? _activos : estado == EstadoAnimal.Vendido ? _vendidos : [])
                    .Where(a => sexo is null || a.Sexo == sexo).ToList());
        _corrales.Setup(r => r.ListarAsync(RanchoIdDePrueba, false)).ReturnsAsync(new List<Corral> { _norte, _tres });
        _vacunaciones.Setup(r => r.ListarDeActivosAsync(RanchoIdDePrueba)).ReturnsAsync(new List<Vacunacion>());
        _vacunaciones.Setup(r => r.ListarPorAnimalAsync(It.IsAny<Guid>())).ReturnsAsync(new List<Vacunacion>());
        _preneces.Setup(r => r.ListarAbiertasConPartoHastaAsync(RanchoIdDePrueba, It.IsAny<DateOnly>())).ReturnsAsync(new List<Prenez>());
        _usuarios.Setup(r => r.ListarActivosAsync(RanchoIdDePrueba)).ReturnsAsync(new List<Usuario>
        {
            new() { Id = Guid.NewGuid(), Nombre = "Ana Vega", Rol = RolUsuario.Propietario },
            new() { Id = Guid.NewGuid(), Nombre = "Laura Rojas", Rol = RolUsuario.Veterinario },
        });
        _publicador.Setup(p => p.PublicarAsync(It.IsAny<IEventoRancho>())).Callback<IEventoRancho>(_publicados.Add).Returns(Task.CompletedTask);

        Agregar("AR-001", SexoAnimal.Hembra, "Nelore", _norte, 420m);
        Agregar("AR-002", SexoAnimal.Hembra, "Brahman", _tres, null);
        Agregar("AR-003", SexoAnimal.Macho, "Nelore", _tres, 500m);
        _vendidos.Add(new Animal { Id = Guid.NewGuid(), Arete = "AR-009", Sexo = SexoAnimal.Macho, Raza = "Nelore", Estado = EstadoAnimal.Vendido });
    }

    private void Agregar(string arete, SexoAnimal sexo, string raza, Corral? corral, decimal? peso) =>
        _activos.Add(new Animal
        {
            Id = Guid.NewGuid(), RanchoId = RanchoIdDePrueba, Arete = arete, Sexo = sexo, Raza = raza,
            CorralId = corral?.Id, Corral = corral, Peso = peso, Estado = EstadoAnimal.Activo,
        });

    private AsistenteService CrearServicio(RolUsuario rol = RolUsuario.Propietario)
    {
        var currentUser = new Mock<ICurrentUserContext>();
        currentUser.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        currentUser.Setup(c => c.Rol).Returns(rol);
        return new AsistenteService(_animales.Object, _corrales.Object, _vacunaciones.Object, _preneces.Object,
            _usuarios.Object, _publicador.Object, currentUser.Object);
    }

    [Fact]
    public void Normaliza_TildesSignosYMayusculas()
    {
        Assert.Equal("cuantas vacas hay en el corral 3", PreguntaAsistente.Normalizar("¿Cuántas VACAS hay en el corral 3?"));
        Assert.Equal("prenadas", PreguntaAsistente.Normalizar("Preñadas"));
    }

    [Theory]
    [InlineData("¿Cuántos animales hay?", "Hay 3 animales activos.")]
    [InlineData("¿Cuántas vacas hay en el corral 3?", "Hay 1 hembra activa en el corral «Corral 3».")]
    [InlineData("cuantas hembras hay en el corral norte", "Hay 1 hembra activa en el corral «Norte».")]
    [InlineData("¿Cuántos machos de raza Nelore hay?", "Hay 1 macho activo de raza Nelore.")]
    [InlineData("¿Cuántos animales Nelore hay?", "Hay 2 animales activos de raza Nelore.")]
    [InlineData("¿Cuántos animales se vendieron?", "Hay 1 animal vendido.")]
    [InlineData("¿Cuántos corrales hay?", "Hay 2 corrales activos.")]
    public async Task Cantidades_CoincidenConLosDatos(string pregunta, string esperada)
    {
        var respuesta = await CrearServicio().ConsultarAsync(pregunta);

        Assert.True(respuesta.Reconocida);
        Assert.False(respuesta.SinDatos);
        Assert.Equal(esperada, respuesta.Respuesta);
    }

    [Fact]
    public async Task CorralInexistente_LoDiceSinInventar()
    {
        var respuesta = await CrearServicio().ConsultarAsync("¿Cuántos animales hay en el corral Sur?");

        Assert.Contains("No encontré el corral «sur»", respuesta.Respuesta);
    }

    [Fact]
    public async Task PreguntaNoReconocida_DevuelveEjemplosYNoInventa()
    {
        var respuesta = await CrearServicio().ConsultarAsync("¿Va a llover mañana?");

        Assert.False(respuesta.Reconocida);
        Assert.NotEmpty(respuesta.Ejemplos);
        Assert.DoesNotContain(respuesta.Respuesta, c => char.IsDigit(c));
    }

    [Fact]
    public async Task PesoDeUnAnimal_YPromedio()
    {
        var servicio = CrearServicio();

        Assert.Equal("El animal AR-001 pesa 420 kg.", (await servicio.ConsultarAsync("¿Cuánto pesa el AR-001?")).Respuesta);
        Assert.Equal("El peso promedio es 460 kg (2 animales con peso registrado).",
            (await servicio.ConsultarAsync("¿Cuál es el peso promedio?")).Respuesta);
    }

    [Fact]
    public async Task AreteInexistente_LoDice()
    {
        var respuesta = await CrearServicio().ConsultarAsync("¿Cuánto pesa el ZZ-999?");

        Assert.Equal("No encontré un animal activo con el arete ZZ-999.", respuesta.Respuesta);
    }

    [Fact]
    public async Task DatoFaltante_DiceElResponsableYLeAvisa()
    {
        // HU-38: AR-002 no tiene peso; responsable de pesajes = Encargado de
        // corrales. No hay ninguno, así que es el propietario (RN-12).
        var respuesta = await CrearServicio().ConsultarAsync("¿Cuánto pesa el AR-002?");

        Assert.True(respuesta.SinDatos);
        Assert.StartsWith(AsistenteService.MensajeSinDatos, respuesta.Respuesta);
        Assert.Equal("Ana Vega", respuesta.Responsable);
        var evento = Assert.IsType<DatoFaltante>(Assert.Single(_publicados));
        Assert.Equal(RolUsuario.EncargadoCorrales, evento.Responsable);
    }

    [Fact]
    public async Task VacunacionFaltante_ElResponsableEsElVeterinario()
    {
        var respuesta = await CrearServicio().ConsultarAsync("¿Cuándo se vacunó el AR-003?");

        Assert.True(respuesta.SinDatos);
        Assert.Equal("Laura Rojas", respuesta.Responsable);
        Assert.Contains("Laura Rojas (Veterinario)", respuesta.Respuesta);
    }

    [Fact]
    public async Task CorralDeUnAnimal()
    {
        var respuesta = await CrearServicio().ConsultarAsync("¿En qué corral está el AR-001?");

        Assert.Equal("El animal AR-001 está en el corral «Norte».", respuesta.Respuesta);
    }

    [Fact]
    public async Task UnRolSinAccesoAlModulo_NoRecibeElDato()
    {
        // El socio ve todo en lectura; para probar la regla se usa un módulo
        // que ningún rol de colaborador gestiona: se simula con un rol inválido.
        var respuesta = await CrearServicio((RolUsuario)99).ConsultarAsync("¿Cuántos animales hay?");

        Assert.Equal("Tu rol no tiene acceso a esa información.", respuesta.Respuesta);
        _animales.Verify(r => r.BuscarAsync(It.IsAny<Guid>(), It.IsAny<string?>(), It.IsAny<EstadoAnimal>(), It.IsAny<SexoAnimal?>(), It.IsAny<string?>()), Times.Never);
    }
}
