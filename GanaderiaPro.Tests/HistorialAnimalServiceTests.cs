using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-22: línea de tiempo del animal.
public class HistorialAnimalServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();

    private readonly Mock<IAnimalRepository> _animales = new();
    private readonly Mock<IVacunacionRepository> _vacunaciones = new();
    private readonly Mock<ITratamientoRepository> _tratamientos = new();
    private readonly Mock<IPesajeRepository> _pesajes = new();
    private readonly Mock<IPrenezRepository> _preneces = new();
    private readonly Mock<IMovimientoCorralRepository> _movimientos = new();
    private readonly Mock<IEventoEstadoAnimalRepository> _estados = new();
    private readonly Animal _animal = new() { Id = Guid.NewGuid(), RanchoId = RanchoIdDePrueba, Arete = "H-01", Sexo = SexoAnimal.Hembra };
    private readonly Usuario _vet = new() { Id = Guid.NewGuid(), Nombre = "Laura Rojas", Rol = RolUsuario.Veterinario };

    public HistorialAnimalServiceTests()
    {
        _animales.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, _animal.Id)).ReturnsAsync(_animal);
        _vacunaciones.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Vacunacion>());
        _tratamientos.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Tratamiento>());
        _pesajes.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Pesaje>());
        _preneces.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Prenez>());
        _movimientos.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<MovimientoCorral>());
        _estados.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<EventoEstadoAnimal>());
    }

    private HistorialAnimalService CrearServicio()
    {
        var currentUser = new Mock<ICurrentUserContext>();
        currentUser.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        return new HistorialAnimalService(_animales.Object, _vacunaciones.Object, _tratamientos.Object, _pesajes.Object,
            _preneces.Object, _movimientos.Object, _estados.Object, currentUser.Object);
    }

    [Fact]
    public async Task SinEventos_DevuelveListaVacia()
    {
        Assert.Empty(await CrearServicio().ListarAsync(_animal.Id));
    }

    [Fact]
    public async Task AnimalDeOtroRancho_NoSeEncuentra()
    {
        // RN-16.
        await Assert.ThrowsAsync<RecursoNoEncontradoException>(() => CrearServicio().ListarAsync(Guid.NewGuid()));
    }


    [Fact]
    public async Task BajaYReactivacion_QuedanEnElHistorialConUsuario()
    {
        var fechaBaja = new DateOnly(2026, 11, 10);
        var fechaReactivacion = new DateOnly(2026, 11, 12);
        _estados.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<EventoEstadoAnimal>
        {
            new()
            {
                Id = Guid.NewGuid(),
                AnimalId = _animal.Id,
                EstadoAnterior = EstadoAnimal.Activo,
                EstadoNuevo = EstadoAnimal.Vendido,
                FechaEvento = fechaBaja,
                FechaRegistro = fechaBaja.ToDateTime(new TimeOnly(12, 0), DateTimeKind.Utc),
                Usuario = _vet,
            },
            new()
            {
                Id = Guid.NewGuid(),
                AnimalId = _animal.Id,
                EstadoAnterior = EstadoAnimal.Vendido,
                EstadoNuevo = EstadoAnimal.Activo,
                FechaEvento = fechaReactivacion,
                FechaRegistro = fechaReactivacion.ToDateTime(new TimeOnly(12, 0), DateTimeKind.Utc),
                Usuario = _vet,
            },
        });

        var eventos = await CrearServicio().ListarAsync(_animal.Id);

        Assert.Equal(new[] { "Reactivacion", "Baja" }, eventos.Select(e => e.Tipo));
        Assert.All(eventos, e => Assert.Equal("Laura Rojas", e.Usuario));
        Assert.Equal(fechaReactivacion, eventos[0].Fecha);
        // RC-11: las bajas y reactivaciones se filtran como «Estado».
        Assert.All(eventos, e => Assert.Equal("Estado", e.Categoria));
    }

    [Fact]
    public async Task UnaBajaAntigua_SinEventoDeEstado_SeMuestraIgual()
    {
        var fechaBaja = new DateOnly(2026, 8, 3);
        _animal.Estado = EstadoAnimal.Fallecido;
        _animal.FechaBaja = fechaBaja;

        var eventos = await CrearServicio().ListarAsync(_animal.Id);

        var baja = Assert.Single(eventos);
        Assert.Equal("Baja", baja.Tipo);
        Assert.Equal("Estado", baja.Categoria);
        Assert.Equal(fechaBaja, baja.Fecha);
    }

    [Fact]
    public async Task ElParto_MuestraQuienLoRegistro_AunqueSeaOtroQueElDelServicio()
    {
        var capataz = new Usuario { Id = Guid.NewGuid(), Nombre = "Pedro Suárez", Rol = RolUsuario.EncargadoCorrales };
        _preneces.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Prenez>
        {
            new()
            {
                Id = Guid.NewGuid(), AnimalId = _animal.Id, FechaServicio = new DateOnly(2026, 1, 10),
                FechaProbableParto = new DateOnly(2026, 10, 20), FechaParto = new DateOnly(2026, 10, 25),
                RegistradoPor = _vet, PartoRegistradoPor = capataz,
            },
        });

        var eventos = await CrearServicio().ListarAsync(_animal.Id);

        Assert.Equal(new[] { "Parto", "Servicio" }, eventos.Select(e => e.Tipo).ToArray());
        Assert.Equal("Pedro Suárez", eventos[0].Usuario);
        Assert.Equal("Reproduccion", eventos[0].Categoria);
        Assert.Equal("Laura Rojas", eventos[1].Usuario);
    }

    [Fact]
    public async Task JuntaTodosLosEventos_DelMasRecienteAlMasAntiguo_ConQuienLosRegistro()
    {
        var aftosa = new Vacuna { Id = Guid.NewGuid(), Nombre = "Fiebre aftosa" };
        _vacunaciones.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Vacunacion>
        {
            new() { Id = Guid.NewGuid(), AnimalId = _animal.Id, Vacuna = aftosa, Dosis = "2 ml", FechaAplicacion = new DateOnly(2026, 10, 1), Veterinario = _vet },
        });
        _tratamientos.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Tratamiento>
        {
            new() { Id = Guid.NewGuid(), AnimalId = _animal.Id, Diagnostico = "Mastitis", Medicamento = "Penicilina", Dosis = "10 ml", FechaInicio = new DateOnly(2026, 10, 20), DuracionDias = 5, Veterinario = _vet },
        });
        _pesajes.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Pesaje>
        {
            new() { Id = Guid.NewGuid(), AnimalId = _animal.Id, Fecha = new DateOnly(2026, 9, 15), Peso = 420.5m },
        });
        _preneces.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Prenez>
        {
            new()
            {
                Id = Guid.NewGuid(), AnimalId = _animal.Id, FechaServicio = new DateOnly(2026, 1, 10),
                FechaProbableParto = new DateOnly(2026, 10, 20), FechaParto = new DateOnly(2026, 10, 25), RegistradoPor = _vet,
            },
        });
        _movimientos.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<MovimientoCorral>
        {
            new() { Id = Guid.NewGuid(), AnimalId = _animal.Id, CorralOrigen = "Norte", CorralDestino = "Sur", Fecha = new DateTime(2026, 11, 2, 15, 0, 0, DateTimeKind.Utc), Usuario = _vet },
        });

        var eventos = await CrearServicio().ListarAsync(_animal.Id);

        Assert.Equal(
            new[] { "MovimientoCorral", "Parto", "Tratamiento", "Vacunacion", "Pesaje", "Servicio" },
            eventos.Select(e => e.Tipo).ToArray());
        Assert.Equal("Pasó del corral «Norte» a «Sur»", eventos[0].Descripcion);
        Assert.Equal("Laura Rojas", eventos[0].Usuario);
        Assert.Equal("Fiebre aftosa · dosis 2 ml", eventos[3].Descripcion);
        // Pesajes de antes de esta versión no tienen usuario.
        Assert.Null(eventos[4].Usuario);
        // RC-11: cada evento con su categoría para filtrar.
        Assert.Equal(
            new[] { "Corrales", "Reproduccion", "Sanidad", "Sanidad", "Pesajes", "Reproduccion" },
            eventos.Select(e => e.Categoria).ToArray());
    }

    [Fact]
    public async Task UnTratamiento_MuestraDiagnosticoMedicamentoEstado_SusSeguimientosYSuFin()
    {
        // RC-11
        var inicio = new DateOnly(2026, 10, 20);
        var registro = new DateTime(2026, 10, 20, 12, 0, 0, DateTimeKind.Utc);
        _tratamientos.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Tratamiento>
        {
            new()
            {
                Id = Guid.NewGuid(), AnimalId = _animal.Id, Diagnostico = "Neumonía", Medicamento = "Oxitetraciclina",
                Dosis = "10 ml", FechaInicio = inicio, DuracionDias = 7, Veterinario = _vet, FechaRegistro = registro,
                Resultado = ResultadoTratamiento.Recuperado, FechaFinalizacion = inicio.AddDays(2), FinalizadoPor = _vet,
                Seguimientos =
                [
                    new() { Fecha = inicio, Evolucion = EvolucionTratamiento.SinCambios, RegistradoPor = _vet, FechaRegistro = registro.AddHours(1) },
                    new() { Fecha = inicio.AddDays(2), Evolucion = EvolucionTratamiento.Mejora, Nota = "Ya no tose", RegistradoPor = _vet, FechaRegistro = registro.AddDays(2) },
                ],
            },
        });

        var eventos = await CrearServicio().ListarAsync(_animal.Id);

        Assert.Equal(
            new[] { "FinTratamiento", "SeguimientoTratamiento", "SeguimientoTratamiento", "Tratamiento" },
            eventos.Select(e => e.Tipo).ToArray());
        Assert.Equal("Neumonía · resultado: Recuperado", eventos[0].Descripcion);
        Assert.Equal("Neumonía (día 3 de 7): Mejora · Ya no tose", eventos[1].Descripcion);
        Assert.Equal("Neumonía · Oxitetraciclina 10 ml, 7 días · finalizado: Recuperado", eventos[3].Descripcion);
        Assert.All(eventos, e => Assert.Equal("Sanidad", e.Categoria));
    }

    [Fact]
    public async Task ElDiagnosticoDePrenezYElAborto_TienenSuPropioTipo()
    {
        // RC-11
        _preneces.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Prenez>
        {
            new()
            {
                Id = Guid.NewGuid(), AnimalId = _animal.Id, FechaServicio = new DateOnly(2026, 6, 1),
                FechaProbableParto = new DateOnly(2027, 3, 11), Diagnostico = DiagnosticoPrenez.Confirmada,
                FechaDiagnostico = new DateOnly(2026, 7, 15), FechaAborto = new DateOnly(2026, 9, 1), RegistradoPor = _vet,
            },
        });

        var eventos = await CrearServicio().ListarAsync(_animal.Id);

        Assert.Equal(new[] { "Aborto", "DiagnosticoPrenez", "Servicio" }, eventos.Select(e => e.Tipo).ToArray());
        Assert.Equal("Preñez confirmada", eventos[1].Descripcion);
        Assert.All(eventos, e => Assert.Equal("Reproduccion", e.Categoria));
    }
}
