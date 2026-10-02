using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

public class AnimalServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();

    private static AnimalService CrearServicio(Mock<IAnimalRepository> repoMock)
    {
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        var unitOfWorkMock = new Mock<IUnitOfWork>();
        return new AnimalService(repoMock.Object, currentUserMock.Object, unitOfWorkMock.Object);
    }

    [Fact]
    public async Task Registrar_ConAreteDuplicado_LanzaReglaDeNegocioException()
    {
        // RN-01: el arete es único dentro del rancho.
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ExisteAreteAsync(RanchoIdDePrueba, "A001")).ReturnsAsync(true);
        var service = CrearServicio(repoMock);

        var request = new RegistrarAnimalRequest("A001", SexoAnimal.Hembra, "Holstein", 350);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));

        repoMock.Verify(r => r.Agregar(It.IsAny<Animal>()), Times.Never);
    }

    [Fact]
    public async Task Registrar_ConAreteNuevo_LoGuardaConElRanchoIdDelUsuarioActual()
    {
        // RN-16: el RanchoId siempre sale del contexto del servidor, nunca de un dato que mande el cliente.
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ExisteAreteAsync(RanchoIdDePrueba, "A002")).ReturnsAsync(false);

        Animal? animalGuardado = null;
        repoMock.Setup(r => r.Agregar(It.IsAny<Animal>()))
            .Callback<Animal>(a => animalGuardado = a);

        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A002", SexoAnimal.Macho, "Angus", 400);

        var resultado = await service.RegistrarAsync(request);

        Assert.NotNull(animalGuardado);
        Assert.Equal(RanchoIdDePrueba, animalGuardado!.RanchoId);
        Assert.Equal(EstadoAnimal.Activo, animalGuardado.Estado);
        Assert.Equal("A002", resultado.Arete);
    }

    [Fact]
    public async Task Buscar_SinEstadoEspecificado_FiltraPorActivo()
    {
        // RN-04: por defecto solo se muestran animales Activos.
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.BuscarAsync(RanchoIdDePrueba, null, EstadoAnimal.Activo, null, null))
            .ReturnsAsync(new List<Animal>());

        var service = CrearServicio(repoMock);
        await service.BuscarAsync(null, null, null, null);

        repoMock.Verify(r => r.BuscarAsync(RanchoIdDePrueba, null, EstadoAnimal.Activo, null, null), Times.Once);
    }

    [Fact]
    public async Task Buscar_SiempreUsaElRanchoIdDelUsuarioActual()
    {
        // RN-16 aplicado también a la búsqueda.
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.BuscarAsync(
                It.IsAny<Guid>(), It.IsAny<string?>(), It.IsAny<EstadoAnimal>(), It.IsAny<SexoAnimal?>(), It.IsAny<string?>()))
            .ReturnsAsync(new List<Animal>());

        var service = CrearServicio(repoMock);
        await service.BuscarAsync("A0", EstadoAnimal.Vendido, SexoAnimal.Hembra, "Holstein");

        repoMock.Verify(
            r => r.BuscarAsync(RanchoIdDePrueba, "A0", EstadoAnimal.Vendido, SexoAnimal.Hembra, "Holstein"),
            Times.Once);
    }

    [Fact]
    public async Task ObtenerPorId_DeOtroRanchoOInexistente_LanzaRecursoNoEncontrado()
    {
        // RN-16: un animal de otro rancho (o que no existe) se trata igual — "no encontrado".
        var repoMock = new Mock<IAnimalRepository>();
        var idAjeno = Guid.NewGuid();
        repoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, idAjeno)).ReturnsAsync((Animal?)null);
        var service = CrearServicio(repoMock);

        await Assert.ThrowsAsync<RecursoNoEncontradoException>(() => service.ObtenerPorIdAsync(idAjeno));
    }

    [Fact]
    public async Task Editar_ConDatosValidos_ActualizaLosCampos()
    {
        var id = Guid.NewGuid();
        var animal = new Animal { Id = id, RanchoId = RanchoIdDePrueba, Arete = "A003", Sexo = SexoAnimal.Macho, Raza = "Angus", Estado = EstadoAnimal.Activo };

        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, id)).ReturnsAsync(animal);
        repoMock.Setup(r => r.ExisteAreteAsync(RanchoIdDePrueba, "A003-editado", id)).ReturnsAsync(false);

        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A003-editado", SexoAnimal.Hembra, "Holstein", 280);

        var resultado = await service.EditarAsync(id, request);

        Assert.Equal("A003-editado", resultado.Arete);
        Assert.Equal(SexoAnimal.Hembra, resultado.Sexo);
        Assert.Equal("Holstein", resultado.Raza);
        Assert.Equal(280, resultado.Peso);
    }

    [Fact]
    public async Task Editar_ConAreteQueYaUsaOtroAnimal_LanzaExcepcion()
    {
        var id = Guid.NewGuid();
        var animal = new Animal { Id = id, RanchoId = RanchoIdDePrueba, Arete = "A004" };

        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, id)).ReturnsAsync(animal);
        repoMock.Setup(r => r.ExisteAreteAsync(RanchoIdDePrueba, "A005", id)).ReturnsAsync(true);

        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A005", SexoAnimal.Macho, "Angus", null);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.EditarAsync(id, request));
    }

    [Fact]
    public async Task Eliminar_AnimalSinEventos_LoElimina()
    {
        var id = Guid.NewGuid();
        var animal = new Animal { Id = id, RanchoId = RanchoIdDePrueba, Arete = "A006" };

        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ObtenerPorIdAsync(RanchoIdDePrueba, id)).ReturnsAsync(animal);

        var service = CrearServicio(repoMock);
        await service.EliminarAsync(id);

        repoMock.Verify(r => r.Eliminar(animal), Times.Once);
    }

    [Fact]
    public async Task Registrar_ConFechaDeNacimientoFutura_LanzaExcepcion()
    {
        // RN-14: no se registran fechas futuras.
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var manana = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(1);
        var request = new RegistrarAnimalRequest("A010", SexoAnimal.Hembra, "Nelore", null, FechaNacimiento: manana);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));

        Assert.Contains("fecha de nacimiento", ex.Message);
        repoMock.Verify(r => r.Agregar(It.IsAny<Animal>()), Times.Never);
    }

    [Theory]
    [InlineData(-50)]
    [InlineData(0)]
    [InlineData(1600)]
    public async Task Registrar_ConPesoAlNacerFueraDeRango_LanzaExcepcion(decimal pesoNacimiento)
    {
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A011", SexoAnimal.Macho, "Gyr", null, PesoNacimiento: pesoNacimiento);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));
    }

    [Fact]
    public async Task Registrar_SinRaza_LanzaExcepcion()
    {
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A012", SexoAnimal.Macho, "  ", null);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));
    }

    [Fact]
    public async Task RegistrarLote_RegistraLasValidasEInformaLasRechazadas()
    {
        // HU-66: las filas válidas se registran y las inválidas se informan con su número de fila.
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ExisteAreteAsync(RanchoIdDePrueba, It.IsAny<string>(), null)).ReturnsAsync(false);
        repoMock.Setup(r => r.ExisteAreteAsync(RanchoIdDePrueba, "B-EXISTE", null)).ReturnsAsync(true);

        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        var unitOfWorkMock = new Mock<IUnitOfWork>();
        var service = new AnimalService(repoMock.Object, currentUserMock.Object, unitOfWorkMock.Object);

        var manana = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(1);
        var filas = new List<RegistrarAnimalRequest>
        {
            new("B-01", SexoAnimal.Hembra, "Nelore", null, Nombre: "Rita"),
            new("B-01", SexoAnimal.Macho, "Nelore", null),
            new("B-EXISTE", SexoAnimal.Hembra, "Gyr", null),
            new("B-03", SexoAnimal.Hembra, "Gyr", null, FechaNacimiento: manana),
            new("B-04", SexoAnimal.Macho, "Brahman", 420),
        };

        var resultado = await service.RegistrarLoteAsync(filas);

        Assert.Equal(new[] { "B-01", "B-04" }, resultado.Registrados.Select(a => a.Arete));
        Assert.Equal(new[] { 2, 3, 4 }, resultado.Rechazados.Select(r => r.Fila));
        Assert.Contains("repetido", resultado.Rechazados[0].Motivo);
        repoMock.Verify(r => r.Agregar(It.IsAny<Animal>()), Times.Exactly(2));
        unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task ObtenerResumen_CuentaActivosPorSexoYBajas()
    {
        // HU-67: las bajas no cuentan como activos (RN-04).
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ContarPorEstadoYSexoAsync(RanchoIdDePrueba)).ReturnsAsync(new List<ConteoAnimales>
        {
            new(EstadoAnimal.Activo, SexoAnimal.Hembra, 7),
            new(EstadoAnimal.Activo, SexoAnimal.Macho, 3),
            new(EstadoAnimal.Vendido, SexoAnimal.Macho, 2),
            new(EstadoAnimal.Fallecido, SexoAnimal.Hembra, 1),
        });
        var service = CrearServicio(repoMock);

        var resumen = await service.ObtenerResumenAsync();

        Assert.Equal(new ResumenAnimalesResponse(10, 7, 3, 2, 1), resumen);
    }
}
