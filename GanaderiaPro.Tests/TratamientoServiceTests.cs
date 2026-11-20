using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-57: tratamientos veterinarios.
public class TratamientoServiceTests
{
    private static readonly Guid RanchoId = Guid.NewGuid();
    private static readonly Guid VeterinarioId = Guid.NewGuid();
    private static readonly DateOnly Hoy = FechaRancho.Hoy();

    private static Animal Animal(EstadoAnimal estado = EstadoAnimal.Activo) => new()
    {
        Id = Guid.NewGuid(),
        RanchoId = RanchoId,
        Arete = "AR-020",
        Sexo = SexoAnimal.Macho,
        Raza = "Brahman",
        Estado = estado,
        FechaNacimiento = Hoy.AddYears(-2),
    };

    private static (TratamientoService Servicio, Mock<ITratamientoRepository> Repo, Mock<IUnitOfWork> Uow) Crear(
        Animal animal, params Tratamiento[] existentes)
    {
        var animales = new Mock<IAnimalRepository>();
        animales.Setup(r => r.ObtenerPorIdAsync(RanchoId, animal.Id)).ReturnsAsync(animal);
        var repo = new Mock<ITratamientoRepository>();
        repo.Setup(r => r.ListarPorAnimalAsync(animal.Id)).ReturnsAsync(existentes);
        foreach (var t in existentes)
        {
            repo.Setup(r => r.ObtenerPorIdAsync(animal.Id, t.Id)).ReturnsAsync(t);
        }
        var usuarios = new Mock<IUsuarioRepository>();
        usuarios.Setup(r => r.ObtenerPorIdAsync(VeterinarioId)).ReturnsAsync(new Usuario { Id = VeterinarioId, Nombre = "Dra. Rojas" });
        var usuario = new Mock<ICurrentUserContext>();
        usuario.Setup(u => u.RanchoId).Returns(RanchoId);
        usuario.Setup(u => u.UsuarioId).Returns(VeterinarioId);
        var uow = new Mock<IUnitOfWork>();
        return (new TratamientoService(repo.Object, animales.Object, usuarios.Object, usuario.Object, uow.Object), repo, uow);
    }

    private static RegistrarTratamientoRequest Pedido(DateOnly? inicio = null, int duracion = 5, string diagnostico = "Neumonía") =>
        new(diagnostico, "Oxitetraciclina", "10 ml", inicio ?? Hoy, duracion);

    [Fact]
    public async Task Registrar_GuardaElTratamientoConElVeterinarioQueLoRegistra()
    {
        var animal = Animal();
        var (servicio, repo, uow) = Crear(animal);
        Tratamiento? guardado = null;
        repo.Setup(r => r.Agregar(It.IsAny<Tratamiento>())).Callback<Tratamiento>(t => guardado = t);

        var r = await servicio.RegistrarAsync(animal.Id, Pedido(Hoy.AddDays(-2), duracion: 5));

        Assert.Equal(VeterinarioId, guardado?.VeterinarioId);
        Assert.Equal("Dra. Rojas", r.Veterinario);
        Assert.Equal(Hoy.AddDays(2), r.FechaFin);
        Assert.True(r.EnCurso);
        uow.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-3)]
    [InlineData(366)]
    public async Task Registrar_ConDuracionFueraDeRango_SeRechaza(int duracion)
    {
        var animal = Animal();
        var (servicio, repo, _) = Crear(animal);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAsync(animal.Id, Pedido(duracion: duracion)));

        Assert.Contains("duración", ex.Message);
        repo.Verify(r => r.Agregar(It.IsAny<Tratamiento>()), Times.Never);
    }

    [Fact]
    public async Task Registrar_ConFechaFutura_SeRechaza()
    {
        var animal = Animal();
        var (servicio, _, _) = Crear(animal);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAsync(animal.Id, Pedido(Hoy.AddDays(1))));
    }

    [Fact]
    public async Task Registrar_AnteriorAlNacimiento_SeRechaza()
    {
        var animal = Animal();
        var (servicio, _, _) = Crear(animal);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAsync(animal.Id, Pedido(animal.FechaNacimiento!.Value.AddDays(-1))));
    }

    [Fact]
    public async Task Registrar_SinDiagnostico_SeRechaza()
    {
        var animal = Animal();
        var (servicio, _, _) = Crear(animal);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAsync(animal.Id, Pedido(diagnostico: "  ")));
    }

    [Fact]
    public async Task Registrar_ConObservacionSoloNumerica_LanzaExcepcion()
    {
        // RC-07: «60» solo no describe nada.
        var animal = Animal();
        var (servicio, _, _) = Crear(animal);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAsync(animal.Id, Pedido() with { Observacion = "60" }));

        Assert.Contains("describir algo", ex.Message);
    }

    [Theory]
    [InlineData(EstadoAnimal.Vendido)]
    [InlineData(EstadoAnimal.Fallecido)]
    public async Task Registrar_EnUnAnimalDadoDeBaja_SeRechaza(EstadoAnimal estado)
    {
        var animal = Animal(estado);
        var (servicio, repo, _) = Crear(animal);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.RegistrarAsync(animal.Id, Pedido()));
        repo.Verify(r => r.Agregar(It.IsAny<Tratamiento>()), Times.Never);
    }

    [Fact]
    public async Task UnAnimalDeOtroRancho_NoSeEncuentra()
    {
        var (servicio, _, _) = Crear(Animal());

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(() => servicio.RegistrarAsync(Guid.NewGuid(), Pedido()));
    }

    [Fact]
    public async Task Listar_IndicaSiCadaTratamientoSigueEnCurso()
    {
        var animal = Animal();
        Tratamiento T(DateOnly inicio, int dias) => new()
        {
            Id = Guid.NewGuid(), AnimalId = animal.Id, Diagnostico = "Diarrea", Medicamento = "Sulfas", Dosis = "5 ml",
            FechaInicio = inicio, DuracionDias = dias, Veterinario = new Usuario { Nombre = "Dra. Rojas" },
        };
        var (servicio, _, _) = Crear(animal, T(Hoy.AddDays(-1), 3), T(Hoy.AddDays(-10), 3));

        var lista = await servicio.ListarAsync(animal.Id);

        Assert.True(lista[0].EnCurso);
        Assert.False(lista[1].EnCurso);
        Assert.Equal("Dra. Rojas", lista[0].Veterinario);
    }

    // ---- RC-08: diagnóstico, dosis con unidad y observación corta

    [Theory]
    [InlineData("5")]
    [InlineData("ml")]
    [InlineData("5 litros")]
    [InlineData("cinco ml")]
    public async Task Registrar_ConDosisSinUnidad_SeRechaza(string dosis)
    {
        var animal = Animal();
        var (servicio, repo, _) = Crear(animal);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAsync(animal.Id, Pedido() with { Dosis = dosis }));

        Assert.Contains("unidad", ex.Message);
        repo.Verify(r => r.Agregar(It.IsAny<Tratamiento>()), Times.Never);
    }

    [Theory]
    [InlineData("5 ml", "5 ml")]
    [InlineData("2,5mg", "2,5 mg")]
    [InlineData("10 UI", "10 UI")]
    [InlineData("1 comprimido", "1 comprimido")]
    [InlineData("3 CC", "3 cc")]
    public async Task Registrar_ConDosisConUnidad_SeAceptaYSeOrdena(string dosis, string guardada)
    {
        var animal = Animal();
        var (servicio, _, _) = Crear(animal);

        var r = await servicio.RegistrarAsync(animal.Id, Pedido() with { Dosis = dosis });

        Assert.Equal(guardada, r.Dosis);
    }

    [Fact]
    public async Task Registrar_ConDiagnosticoDeMasDe100Caracteres_SeRechaza()
    {
        var animal = Animal();
        var (servicio, _, _) = Crear(animal);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAsync(animal.Id, Pedido(diagnostico: new string('a', 101))));

        Assert.Contains("diagnóstico", ex.Message);
    }

    [Fact]
    public async Task Registrar_SinMedicamento_SeRechaza()
    {
        var animal = Animal();
        var (servicio, _, _) = Crear(animal);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAsync(animal.Id, Pedido() with { Medicamento = " " }));

        Assert.Contains("medicamento", ex.Message);
    }

    [Fact]
    public async Task Registrar_ConObservacionDeMasDe300Caracteres_SeRechaza()
    {
        var animal = Animal();
        var (servicio, _, _) = Crear(animal);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAsync(animal.Id, Pedido() with { Observacion = new string('a', 301) }));

        Assert.Contains("300", ex.Message);
    }

    // ---- RC-09: seguimiento y finalización

    private static Tratamiento Existente(Animal animal, DateOnly inicio, int dias, params DateOnly[] seguimientos) => new()
    {
        Id = Guid.NewGuid(),
        AnimalId = animal.Id,
        Diagnostico = "Neumonía",
        Medicamento = "Oxitetraciclina",
        Dosis = "10 ml",
        FechaInicio = inicio,
        DuracionDias = dias,
        VeterinarioId = VeterinarioId,
        Seguimientos = seguimientos
            .Select(f => new SeguimientoTratamiento { Id = Guid.NewGuid(), Fecha = f, Evolucion = EvolucionTratamiento.SinCambios })
            .ToList(),
    };

    [Fact]
    public async Task Listar_UnTratamientoDe7DiasEmpezadoHaceDosDias_MuestraDia3De7()
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-2), 7, Hoy.AddDays(-2), Hoy.AddDays(-1));
        var (servicio, _, _) = Crear(animal, t);

        var r = Assert.Single(await servicio.ListarAsync(animal.Id));

        Assert.Equal(3, r.DiaActual);
        Assert.Equal(EstadoTratamiento.EnCurso, r.Estado);
        Assert.Equal(2, r.Seguimientos.Count);
    }

    [Fact]
    public async Task RegistrarSeguimiento_LoGuardaYLoDevuelveEnElTratamiento()
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-2), 7);
        var (servicio, repo, uow) = Crear(animal, t);

        var r = await servicio.RegistrarSeguimientoAsync(animal.Id, t.Id,
            new RegistrarSeguimientoRequest(Hoy, EvolucionTratamiento.Mejora, "Come mejor y tose menos"));

        var s = Assert.Single(r.Seguimientos);
        Assert.Equal(EvolucionTratamiento.Mejora, s.Evolucion);
        Assert.Equal("Dra. Rojas", s.Usuario);
        repo.Verify(x => x.AgregarSeguimiento(It.Is<SeguimientoTratamiento>(g => g.RegistradoPorId == VeterinarioId)), Times.Once);
        uow.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task RegistrarSeguimiento_DosVecesElMismoDia_SeRechaza()
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-2), 7, Hoy);
        var (servicio, repo, _) = Crear(animal, t);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.RegistrarSeguimientoAsync(animal.Id, t.Id,
            new RegistrarSeguimientoRequest(Hoy, EvolucionTratamiento.Mejora)));

        Assert.Contains("Ya hay un seguimiento", ex.Message);
        repo.Verify(x => x.AgregarSeguimiento(It.IsAny<SeguimientoTratamiento>()), Times.Never);
    }

    [Theory]
    [InlineData(1, "futura")]
    [InlineData(-3, "anterior al inicio")]
    public async Task RegistrarSeguimiento_FueraDelInicioYHoy_SeRechaza(int dias, string mensaje)
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-2), 7);
        var (servicio, _, _) = Crear(animal, t);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.RegistrarSeguimientoAsync(animal.Id, t.Id,
            new RegistrarSeguimientoRequest(Hoy.AddDays(dias), EvolucionTratamiento.Mejora)));

        Assert.Contains(mensaje, ex.Message);
    }

    [Fact]
    public async Task RegistrarSeguimiento_DespuesDelUltimoDia_SeRechaza()
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-10), 3);
        var (servicio, _, _) = Crear(animal, t);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.RegistrarSeguimientoAsync(animal.Id, t.Id,
            new RegistrarSeguimientoRequest(Hoy, EvolucionTratamiento.Mejora)));

        Assert.Contains("último día", ex.Message);
    }

    [Fact]
    public async Task RegistrarSeguimiento_ConNotaSoloNumerica_SeRechaza()
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-2), 7);
        var (servicio, _, _) = Crear(animal, t);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.RegistrarSeguimientoAsync(animal.Id, t.Id,
            new RegistrarSeguimientoRequest(Hoy, EvolucionTratamiento.Mejora, "38")));

        Assert.Contains("describir algo", ex.Message);
    }

    [Fact]
    public async Task RegistrarSeguimiento_EnUnTratamientoFinalizado_SeRechaza()
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-2), 7);
        t.Resultado = ResultadoTratamiento.Recuperado;
        t.FechaFinalizacion = Hoy.AddDays(-1);
        var (servicio, _, _) = Crear(animal, t);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.RegistrarSeguimientoAsync(animal.Id, t.Id,
            new RegistrarSeguimientoRequest(Hoy, EvolucionTratamiento.Mejora)));

        Assert.Contains("finalizado", ex.Message);
    }

    [Fact]
    public async Task Finalizar_AntesDelUltimoDia_LoTermina()
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-2), 7);
        var (servicio, _, uow) = Crear(animal, t);

        var r = await servicio.FinalizarAsync(animal.Id, t.Id, new FinalizarTratamientoRequest(Hoy, ResultadoTratamiento.Recuperado));

        Assert.Equal(EstadoTratamiento.Finalizado, r.Estado);
        Assert.False(r.EnCurso);
        Assert.Equal(ResultadoTratamiento.Recuperado, r.Resultado);
        Assert.Equal(Hoy, r.FechaFinalizacion);
        Assert.Equal(VeterinarioId, t.FinalizadoPorId);
        uow.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task Finalizar_DosVeces_SeRechaza()
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-2), 7);
        t.Resultado = ResultadoTratamiento.Derivado;
        t.FechaFinalizacion = Hoy;
        var (servicio, _, _) = Crear(animal, t);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.FinalizarAsync(animal.Id, t.Id, new FinalizarTratamientoRequest(Hoy, ResultadoTratamiento.Recuperado)));
    }

    [Fact]
    public async Task Finalizar_AntesDelUltimoSeguimiento_SeRechaza()
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-3), 7, Hoy.AddDays(-1));
        var (servicio, _, _) = Crear(animal, t);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => servicio.FinalizarAsync(animal.Id, t.Id,
            new FinalizarTratamientoRequest(Hoy.AddDays(-2), ResultadoTratamiento.SinMejoria)));

        Assert.Contains("último seguimiento", ex.Message);
    }

    [Fact]
    public async Task UnTratamientoVencidoSinResultado_QuedaSinResultadoYSePuedeFinalizar()
    {
        var animal = Animal();
        var t = Existente(animal, Hoy.AddDays(-10), 3);
        var (servicio, _, _) = Crear(animal, t);

        Assert.Equal(EstadoTratamiento.SinResultado, Assert.Single(await servicio.ListarAsync(animal.Id)).Estado);

        var r = await servicio.FinalizarAsync(animal.Id, t.Id, new FinalizarTratamientoRequest(Hoy, ResultadoTratamiento.Recuperado));
        Assert.Equal(EstadoTratamiento.Finalizado, r.Estado);
    }

    [Fact]
    public async Task ListarDelRancho_SeparaLosEnCursoDeLosTerminados()
    {
        var animal = Animal();
        var enCurso = Existente(animal, Hoy.AddDays(-1), 5);
        var finalizado = Existente(animal, Hoy.AddDays(-2), 5);
        finalizado.Resultado = ResultadoTratamiento.Recuperado;
        finalizado.FechaFinalizacion = Hoy;
        var vencido = Existente(animal, Hoy.AddDays(-20), 3);
        foreach (var t in new[] { enCurso, finalizado, vencido })
        {
            t.Animal = animal;
        }
        var (servicio, repo, _) = Crear(animal);
        repo.Setup(r => r.ListarDelRanchoAsync(RanchoId)).ReturnsAsync([enCurso, finalizado, vencido]);

        var enCursoLista = await servicio.ListarDelRanchoAsync(terminados: false);
        var terminadosLista = await servicio.ListarDelRanchoAsync(terminados: true);

        Assert.Equal([enCurso.Id], enCursoLista.Select(t => t.Id));
        Assert.Equal([finalizado.Id, vencido.Id], terminadosLista.Select(t => t.Id));
        Assert.Equal("AR-020", enCursoLista[0].Arete);
    }
}
