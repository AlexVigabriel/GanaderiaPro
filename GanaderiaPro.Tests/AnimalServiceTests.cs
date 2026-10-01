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
}
