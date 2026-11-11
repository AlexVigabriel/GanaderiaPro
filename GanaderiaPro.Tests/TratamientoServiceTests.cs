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
        var usuarios = new Mock<IUsuarioRepository>();
        usuarios.Setup(r => r.ObtenerPorIdAsync(VeterinarioId)).ReturnsAsync(new Usuario { Id = VeterinarioId, Nombre = "Dra. Rojas" });
        var usuario = new Mock<ICurrentUserContext>();
        usuario.Setup(u => u.RanchoId).Returns(RanchoId);
        usuario.Setup(u => u.UsuarioId).Returns(VeterinarioId);
        var uow = new Mock<IUnitOfWork>();
        return (new TratamientoService(repo.Object, animales.Object, usuarios.Object, usuario.Object, uow.Object), repo, uow);
    }

    private static RegistrarTratamientoRequest Pedido(DateOnly? inicio = null, int duracion = 5, string motivo = "Neumonía") =>
        new(motivo, "Oxitetraciclina", "10 ml", inicio ?? Hoy, duracion);

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
    public async Task Registrar_SinMotivo_SeRechaza()
    {
        var animal = Animal();
        var (servicio, _, _) = Crear(animal);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(
            () => servicio.RegistrarAsync(animal.Id, Pedido(motivo: "  ")));
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
            Id = Guid.NewGuid(), AnimalId = animal.Id, Motivo = "Diarrea", Medicamento = "Sulfas", Dosis = "5 ml",
            FechaInicio = inicio, DuracionDias = dias, Veterinario = new Usuario { Nombre = "Dra. Rojas" },
        };
        var (servicio, _, _) = Crear(animal, T(Hoy.AddDays(-1), 3), T(Hoy.AddDays(-10), 3));

        var lista = await servicio.ListarAsync(animal.Id);

        Assert.True(lista[0].EnCurso);
        Assert.False(lista[1].EnCurso);
        Assert.Equal("Dra. Rojas", lista[0].Veterinario);
    }
}
