using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Planes;
using Moq;
using Xunit;

namespace GanaderiaPro.Tests;

public class AnimalServiceTests
{
    private static readonly Guid RanchoIdDePrueba = Guid.NewGuid();

    // La fecha de nacimiento es obligatoria: las pruebas que no la ponen a
    // prueba usan un animal de dos años.
    private static readonly DateOnly HaceDosAnios = FechaRancho.Hoy().AddYears(-2);

    private static AnimalService CrearServicio(Mock<IAnimalRepository> repoMock)
    {
        var currentUserMock = new Mock<ICurrentUserContext>();
        currentUserMock.Setup(c => c.RanchoId).Returns(RanchoIdDePrueba);
        var unitOfWorkMock = new Mock<IUnitOfWork>();
        return new AnimalService(repoMock.Object, currentUserMock.Object, unitOfWorkMock.Object, SinLimites.Plan());
    }

    [Fact]
    public async Task Registrar_ConAreteDuplicado_LanzaReglaDeNegocioException()
    {
        // RN-01: el arete es único dentro del rancho.
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ExisteAreteAsync(RanchoIdDePrueba, "A001", null)).ReturnsAsync(true);
        var service = CrearServicio(repoMock);

        var request = new RegistrarAnimalRequest("A001", SexoAnimal.Hembra, "Holstein", 350, FechaNacimiento: HaceDosAnios);

        await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));

        repoMock.Verify(r => r.Agregar(It.IsAny<Animal>()), Times.Never);
    }

    [Fact]
    public async Task Registrar_ConAreteNuevo_LoGuardaConElRanchoIdDelUsuarioActual()
    {
        // RN-16: el RanchoId siempre sale del contexto del servidor, nunca de un dato que mande el cliente.
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.ExisteAreteAsync(RanchoIdDePrueba, "A002", null)).ReturnsAsync(false);

        Animal? animalGuardado = null;
        repoMock.Setup(r => r.Agregar(It.IsAny<Animal>()))
            .Callback<Animal>(a => animalGuardado = a);

        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A002", SexoAnimal.Macho, "Angus", 400, FechaNacimiento: HaceDosAnios);

        var resultado = await service.RegistrarAsync(request);

        Assert.NotNull(animalGuardado);
        Assert.Equal(RanchoIdDePrueba, animalGuardado!.RanchoId);
        Assert.Equal(EstadoAnimal.Activo, animalGuardado.Estado);
        Assert.Equal("A002", resultado.Arete);
    }

    [Fact]
    public async Task Registrar_ConIdentificacionEnMinusculas_LaGuardaEnMayusculas()
    {
        // RN-01: "ar-007" y "AR-007" son el mismo animal, así que se guarda normalizada.
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("  ar-007 ", SexoAnimal.Hembra, "Nelore", null, FechaNacimiento: HaceDosAnios);

        var resultado = await service.RegistrarAsync(request);

        Assert.Equal("AR-007", resultado.Arete);
        repoMock.Verify(r => r.ExisteAreteAsync(RanchoIdDePrueba, "AR-007", null), Times.Once);
    }

    [Theory]
    [InlineData("AR 001")]
    [InlineData("AR_001")]
    [InlineData("AR/001")]
    [InlineData("AR.001")]
    public async Task Registrar_ConIdentificacionConCaracteresNoPermitidos_LanzaExcepcion(string identificacion)
    {
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest(identificacion, SexoAnimal.Hembra, "Nelore", null, FechaNacimiento: HaceDosAnios);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));

        Assert.Contains("letras, números y guiones", ex.Message);
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
        repoMock.Setup(r => r.ExisteAreteAsync(RanchoIdDePrueba, "A003-B", id)).ReturnsAsync(false);

        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("a003-b", SexoAnimal.Hembra, "Holstein", 280, FechaNacimiento: HaceDosAnios);

        var resultado = await service.EditarAsync(id, request);

        Assert.Equal("A003-B", resultado.Arete);
        Assert.Equal(SexoAnimal.Hembra, resultado.Sexo);
        Assert.Equal("Holstein", resultado.Raza);
        Assert.Equal(280, resultado.Peso);
        Assert.Equal(HaceDosAnios, resultado.FechaNacimiento);
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
        var request = new RegistrarAnimalRequest("A005", SexoAnimal.Macho, "Angus", null, FechaNacimiento: HaceDosAnios);

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
    public async Task Registrar_SinFechaDeNacimiento_LanzaExcepcion()
    {
        // La fecha (aunque sea aproximada) es obligatoria: con ella se calcula edad y categoría.
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A009", SexoAnimal.Hembra, "Nelore", null);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));

        Assert.Contains("obligatoria", ex.Message);
        repoMock.Verify(r => r.Agregar(It.IsAny<Animal>()), Times.Never);
    }

    [Fact]
    public async Task Registrar_ConFechaDeNacimientoFutura_LanzaExcepcion()
    {
        // RN-14: no se registran fechas futuras.
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var manana = FechaRancho.Hoy().AddDays(1);
        var request = new RegistrarAnimalRequest("A010", SexoAnimal.Hembra, "Nelore", null, FechaNacimiento: manana);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));

        Assert.Contains("futura", ex.Message);
        repoMock.Verify(r => r.Agregar(It.IsAny<Animal>()), Times.Never);
    }

    [Fact]
    public async Task Registrar_ConFechaDeNacimientoDeMasDe25Anios_LanzaExcepcion()
    {
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var hace26Anios = FechaRancho.Hoy().AddYears(-26);
        var request = new RegistrarAnimalRequest("A013", SexoAnimal.Hembra, "Nelore", null, FechaNacimiento: hace26Anios);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));

        Assert.Contains("25 años", ex.Message);
    }

    [Theory]
    [InlineData(-50)]
    [InlineData(0)]
    [InlineData(9)]
    [InlineData(81)]
    [InlineData(1600)]
    public async Task Registrar_ConPesoAlNacerFueraDeRango_LanzaExcepcion(decimal pesoNacimiento)
    {
        // Un ternero bovino nace con entre 10 y 80 kg.
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A011", SexoAnimal.Macho, "Gyr", null, FechaNacimiento: HaceDosAnios, PesoNacimiento: pesoNacimiento);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));

        Assert.Contains("peso al nacer", ex.Message);
    }

    [Theory]
    [InlineData(10)]
    [InlineData(80)]
    public async Task Registrar_ConPesoAlNacerEnElLimite_LoRegistra(decimal pesoNacimiento)
    {
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A014", SexoAnimal.Macho, "Gyr", null, FechaNacimiento: HaceDosAnios, PesoNacimiento: pesoNacimiento);

        var resultado = await service.RegistrarAsync(request);

        Assert.Equal(pesoNacimiento, resultado.PesoNacimiento);
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(0)]
    [InlineData(1501)]
    public async Task Registrar_ConPesoActualFueraDeRango_LanzaExcepcion(decimal peso)
    {
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A015", SexoAnimal.Hembra, "Nelore", peso, FechaNacimiento: HaceDosAnios);

        var ex = await Assert.ThrowsAsync<ReglaDeNegocioException>(() => service.RegistrarAsync(request));

        Assert.Contains("peso actual", ex.Message);
    }

    [Fact]
    public async Task Registrar_SinRaza_LanzaExcepcion()
    {
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var request = new RegistrarAnimalRequest("A012", SexoAnimal.Macho, "  ", null, FechaNacimiento: HaceDosAnios);

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
        var service = new AnimalService(repoMock.Object, currentUserMock.Object, unitOfWorkMock.Object, SinLimites.Plan());

        var manana = FechaRancho.Hoy().AddDays(1);
        var filas = new List<RegistrarAnimalRequest>
        {
            new("B-01", SexoAnimal.Hembra, "Nelore", null, Nombre: "Rita", FechaNacimiento: HaceDosAnios),
            // Repetida aunque venga en minúsculas.
            new("b-01", SexoAnimal.Macho, "Nelore", null, FechaNacimiento: HaceDosAnios),
            new("B-EXISTE", SexoAnimal.Hembra, "Gyr", null, FechaNacimiento: HaceDosAnios),
            new("B-03", SexoAnimal.Hembra, "Gyr", null, FechaNacimiento: manana),
            new("B-04", SexoAnimal.Macho, "Brahman", 420, FechaNacimiento: HaceDosAnios),
        };

        var resultado = await service.RegistrarLoteAsync(filas);

        Assert.Equal(new[] { "B-01", "B-04" }, resultado.Registrados.Select(a => a.Arete));
        Assert.Equal(new[] { 2, 3, 4 }, resultado.Rechazados.Select(r => r.Fila));
        Assert.Contains("repetida", resultado.Rechazados[0].Motivo);
        repoMock.Verify(r => r.Agregar(It.IsAny<Animal>()), Times.Exactly(2));
        unitOfWorkMock.Verify(u => u.GuardarCambiosAsync(), Times.Once);
    }

    [Fact]
    public async Task Registrar_HembraMarcadaComoCastrada_SeGuardaSinCastrar()
    {
        // HU-74: la castración solo aplica a machos.
        var repoMock = new Mock<IAnimalRepository>();
        var service = CrearServicio(repoMock);
        var haceTresAnios = FechaRancho.Hoy().AddYears(-3);
        var request = new RegistrarAnimalRequest("A016", SexoAnimal.Hembra, "Nelore", null, FechaNacimiento: haceTresAnios, Castrado: true);

        var resultado = await service.RegistrarAsync(request);

        Assert.False(resultado.Castrado);
        Assert.Equal(CategoriaAnimal.Vaca, resultado.Categoria);
    }

    [Fact]
    public async Task Buscar_PorCategoria_DevuelveSoloEsaCategoria()
    {
        // HU-74: el filtro usa la categoría calculada.
        var hoy = FechaRancho.Hoy();
        var repoMock = new Mock<IAnimalRepository>();
        repoMock.Setup(r => r.BuscarAsync(RanchoIdDePrueba, null, EstadoAnimal.Activo, null, null))
            .ReturnsAsync(new List<Animal>
            {
                new() { Arete = "T-1", Sexo = SexoAnimal.Macho, FechaNacimiento = hoy.AddMonths(-3) },
                new() { Arete = "N-1", Sexo = SexoAnimal.Macho, Castrado = true, FechaNacimiento = hoy.AddMonths(-14) },
                new() { Arete = "N-2", Sexo = SexoAnimal.Macho, Castrado = true, FechaNacimiento = hoy.AddMonths(-40) },
                new() { Arete = "V-1", Sexo = SexoAnimal.Hembra, FechaNacimiento = hoy.AddMonths(-40) },
            });
        var service = CrearServicio(repoMock);

        var novillos = await service.BuscarAsync(null, null, null, null, CategoriaAnimal.Novillo);

        Assert.Equal(new[] { "N-1", "N-2" }, novillos.Select(a => a.Arete));
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
