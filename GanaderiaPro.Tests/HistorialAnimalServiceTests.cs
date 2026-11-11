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
    }

    private HistorialAnimalService CrearServicio()
    {
        var currentUser = new Mock<ICurrentUserContext>();
        currentUser.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        return new HistorialAnimalService(_animales.Object, _vacunaciones.Object, _tratamientos.Object, _pesajes.Object,
            _preneces.Object, _movimientos.Object, currentUser.Object);
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
    public async Task JuntaTodosLosEventos_DelMasRecienteAlMasAntiguo_ConQuienLosRegistro()
    {
        var aftosa = new Vacuna { Id = Guid.NewGuid(), Nombre = "Fiebre aftosa" };
        _vacunaciones.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Vacunacion>
        {
            new() { Id = Guid.NewGuid(), AnimalId = _animal.Id, Vacuna = aftosa, Dosis = "2 ml", FechaAplicacion = new DateOnly(2026, 10, 1), Veterinario = _vet },
        });
        _tratamientos.Setup(r => r.ListarPorAnimalAsync(_animal.Id)).ReturnsAsync(new List<Tratamiento>
        {
            new() { Id = Guid.NewGuid(), AnimalId = _animal.Id, Motivo = "Mastitis", Medicamento = "Penicilina", Dosis = "10 ml", FechaInicio = new DateOnly(2026, 10, 20), DuracionDias = 5, Veterinario = _vet },
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
            ["MovimientoCorral", "Parto", "Tratamiento", "Vacunacion", "Pesaje", "Servicio"],
            eventos.Select(e => e.Tipo).ToArray());
        Assert.Equal("Pasó del corral «Norte» a «Sur»", eventos[0].Descripcion);
        Assert.Equal("Laura Rojas", eventos[0].Usuario);
        Assert.Equal("Fiebre aftosa · dosis 2 ml", eventos[3].Descripcion);
        // Pesajes de antes de esta versión no tienen usuario.
        Assert.Null(eventos[4].Usuario);
    }
}
