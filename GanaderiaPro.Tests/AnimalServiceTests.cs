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
        return new AnimalService(repoMock.Object, currentUserMock.Object);
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

        repoMock.Verify(r => r.AgregarAsync(It.IsAny<Animal>()), Times.Never);
    }

    [Fact]
    public async Task Registrar_ConAreteNuevo_LoGuardaConElRanchoIdDelUsuarioActual()
    {
        // RN-16: el RanchoId siempre sale del contexto del servidor, nunca de un dato que mande el cliente.
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ExisteAreteAsync(RanchoIdDePrueba, "A002")).ReturnsAsync(false);

        Animal? animalGuardado = null;
        repoMock.Setup(r => r.AgregarAsync(It.IsAny<Animal>()))
            .Callback<Animal>(a => animalGuardado = a)
            .Returns(Task.CompletedTask);

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
}
