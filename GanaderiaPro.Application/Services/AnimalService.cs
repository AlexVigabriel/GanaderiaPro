using System.Text.RegularExpressions;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

public class AnimalService : IAnimalService
{
    private const decimal PesoMaximoKg = 1500;
    private const decimal PesoNacimientoMinimoKg = 10;
    private const decimal PesoNacimientoMaximoKg = 80;
    private const int AntiguedadMaximaAnios = 25;
    private const int MaximoFilasPorLote = 500;

    // La identificación (arete o caravana) se guarda en mayúsculas y solo
    // admite letras, números y guiones, para que "ar-001" y "AR-001" sean
    // el mismo animal (RN-01).
    private static readonly Regex FormatoIdentificacion = new("^[A-Z0-9-]+$", RegexOptions.Compiled);

    // RN-14: "hoy" se calcula en la hora de Bolivia, no en UTC. Entre las
    // 20:00 y la medianoche la fecha UTC ya es la de mañana, y una fecha
    // futura pasaba como válida.
    private static readonly TimeZoneInfo ZonaHorariaRancho = TimeZoneInfo.FindSystemTimeZoneById("America/La_Paz");

    private readonly IAnimalRepository _animalRepository;
    private readonly ICurrentUserContext _currentUser;
    private readonly IUnitOfWork _unitOfWork;

    public AnimalService(IAnimalRepository animalRepository, ICurrentUserContext currentUser, IUnitOfWork unitOfWork)
    {
        _animalRepository = animalRepository;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
    }

    public async Task<AnimalResponse> RegistrarAsync(RegistrarAnimalRequest request)
    {
        var error = ValidarDatos(request);
        if (error is not null)
        {
            throw new ReglaDeNegocioException(error);
        }

        var ranchoId = _currentUser.RanchoId;
        var arete = NormalizarIdentificacion(request.Arete);

        // RN-01: el arete es único dentro del rancho, incluso entre animales dados de baja.
        var existeArete = await _animalRepository.ExisteAreteAsync(ranchoId, arete);
        if (existeArete)
        {
            throw new ReglaDeNegocioException($"Ya existe un animal con la identificación '{arete}' en este rancho.");
        }

        var animal = CrearAnimal(ranchoId, request);
        _animalRepository.Agregar(animal);
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(animal);
    }

    // HU-66: carga múltiple. Las filas válidas se registran juntas y las
    // inválidas se devuelven con su número de fila y el motivo.
    public async Task<RegistrarLoteResponse> RegistrarLoteAsync(IReadOnlyList<RegistrarAnimalRequest> filas)
    {
        if (filas.Count == 0)
        {
            throw new ReglaDeNegocioException("No hay animales para cargar.");
        }

        if (filas.Count > MaximoFilasPorLote)
        {
            throw new ReglaDeNegocioException($"Se pueden cargar hasta {MaximoFilasPorLote} animales por vez.");
        }

        var ranchoId = _currentUser.RanchoId;
        var registrados = new List<Animal>();
        var rechazados = new List<FilaRechazada>();
        var aretesDelLote = new HashSet<string>(StringComparer.Ordinal);

        for (var i = 0; i < filas.Count; i++)
        {
            var fila = filas[i];
            var arete = NormalizarIdentificacion(fila.Arete);
            var error = ValidarDatos(fila);

            // RN-01 también dentro de la misma carga, no solo contra la base.
            if (error is null && !aretesDelLote.Add(arete))
            {
                error = "La identificación está repetida en esta carga.";
            }

            if (error is null && await _animalRepository.ExisteAreteAsync(ranchoId, arete))
            {
                error = $"Ya existe un animal con la identificación '{arete}' en este rancho.";
            }

            if (error is not null)
            {
                rechazados.Add(new FilaRechazada(i + 1, arete, error));
                continue;
            }

            var animal = CrearAnimal(ranchoId, fila);
            _animalRepository.Agregar(animal);
            registrados.Add(animal);
        }

        if (registrados.Count > 0)
        {
            await _unitOfWork.GuardarCambiosAsync();
        }

        return new RegistrarLoteResponse(registrados.Select(ToResponse).ToList(), rechazados);
    }

    public async Task<IReadOnlyList<AnimalResponse>> BuscarAsync(
        string? busqueda, EstadoAnimal? estado, SexoAnimal? sexo, string? raza, CategoriaAnimal? categoria = null)
    {
        // RN-04: por defecto solo se muestran animales Activos, salvo que se pida un estado explícito.
        var estadoEfectivo = estado ?? EstadoAnimal.Activo;

        var animales = await _animalRepository.BuscarAsync(_currentUser.RanchoId, busqueda, estadoEfectivo, sexo, raza);
        var respuestas = animales.Select(ToResponse);

        // HU-74: la categoría se calcula (no está en la base), así que se
        // filtra después de buscar. Un rancho tiene a lo sumo unos cientos de animales.
        if (categoria is not null)
        {
            respuestas = respuestas.Where(a => a.Categoria == categoria);
        }

        return respuestas.ToList();
    }

    // HU-67: conteos del rancho actual para las tarjetas del listado.
    public async Task<ResumenAnimalesResponse> ObtenerResumenAsync()
    {
        var conteos = await _animalRepository.ContarPorEstadoYSexoAsync(_currentUser.RanchoId);

        int Sumar(Func<ConteoAnimales, bool> condicion) => conteos.Where(condicion).Sum(c => c.Cantidad);

        return new ResumenAnimalesResponse(
            Activos: Sumar(c => c.Estado == EstadoAnimal.Activo),
            HembrasActivas: Sumar(c => c.Estado == EstadoAnimal.Activo && c.Sexo == SexoAnimal.Hembra),
            MachosActivos: Sumar(c => c.Estado == EstadoAnimal.Activo && c.Sexo == SexoAnimal.Macho),
            Vendidos: Sumar(c => c.Estado == EstadoAnimal.Vendido),
            Fallecidos: Sumar(c => c.Estado == EstadoAnimal.Fallecido));
    }

    public async Task<AnimalResponse> ObtenerPorIdAsync(Guid id)
    {
        var animal = await ObtenerDelRanchoActualAsync(id);
        return ToResponse(animal);
    }

    public async Task<AnimalResponse> EditarAsync(Guid id, RegistrarAnimalRequest request)
    {
        var error = ValidarDatos(request);
        if (error is not null)
        {
            throw new ReglaDeNegocioException(error);
        }

        var animal = await ObtenerDelRanchoActualAsync(id);
        var arete = NormalizarIdentificacion(request.Arete);

        // RN-01: el arete es único dentro del rancho (sin contarse a sí mismo).
        var existeArete = await _animalRepository.ExisteAreteAsync(animal.RanchoId, arete, excluirId: id);
        if (existeArete)
        {
            throw new ReglaDeNegocioException($"Ya existe un animal con la identificación '{arete}' en este rancho.");
        }

        CopiarDatos(request, animal);
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(animal);
    }

    public async Task EliminarAsync(Guid id)
    {
        var animal = await ObtenerDelRanchoActualAsync(id);

        // RN-05: eliminación física solo si no tiene eventos asociados
        // (vacunaciones, tratamientos, pesajes, preñeces, movimientos de
        // corral). Ninguno de esos módulos existe todavía (Sprint 2), así
        // que por ahora esto nunca bloquea — queda listo para cuando existan.
        if (TieneEventosAsociados(animal))
        {
            throw new ReglaDeNegocioException(
                "No se puede eliminar: el animal tiene eventos registrados. Registrá una baja en su lugar.");
        }

        _animalRepository.Eliminar(animal);
        await _unitOfWork.GuardarCambiosAsync();
    }

    // Devuelve el primer problema encontrado en los datos, o null si son válidos.
    private static string? ValidarDatos(RegistrarAnimalRequest request)
    {
        var identificacion = NormalizarIdentificacion(request.Arete);
        if (identificacion.Length == 0)
        {
            return "La identificación es obligatoria.";
        }

        if (identificacion.Length > 50)
        {
            return "La identificación puede tener hasta 50 caracteres.";
        }

        if (!FormatoIdentificacion.IsMatch(identificacion))
        {
            return "La identificación solo puede tener letras, números y guiones.";
        }

        if (string.IsNullOrWhiteSpace(request.Raza))
        {
            return "La raza es obligatoria.";
        }

        // Obligatoria (puede ser aproximada): con ella se calcula la edad y la categoría.
        if (request.FechaNacimiento is not { } nacimiento)
        {
            return "La fecha de nacimiento es obligatoria.";
        }

        // RN-14: no se registran fechas futuras.
        if (nacimiento > Hoy())
        {
            return "La fecha de nacimiento no puede ser futura.";
        }

        if (nacimiento < Hoy().AddYears(-AntiguedadMaximaAnios))
        {
            return $"La fecha de nacimiento no puede tener más de {AntiguedadMaximaAnios} años.";
        }

        if (request.PesoNacimiento is { } pesoNacimiento &&
            (pesoNacimiento < PesoNacimientoMinimoKg || pesoNacimiento > PesoNacimientoMaximoKg))
        {
            return $"El peso al nacer debe estar entre {PesoNacimientoMinimoKg} y {PesoNacimientoMaximoKg} kg.";
        }

        if (request.Peso is { } peso && (peso <= 0 || peso > PesoMaximoKg))
        {
            return $"El peso actual debe ser mayor que 0 y de hasta {PesoMaximoKg} kg.";
        }

        if (request.Nombre?.Trim().Length > 100)
        {
            return "El nombre puede tener hasta 100 caracteres.";
        }

        if (request.Color?.Trim().Length > 40)
        {
            return "El color puede tener hasta 40 caracteres.";
        }

        if (request.Observaciones?.Trim().Length > 500)
        {
            return "Las observaciones pueden tener hasta 500 caracteres.";
        }

        return null;
    }

    private static DateOnly Hoy() =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, ZonaHorariaRancho));

    private static string NormalizarIdentificacion(string? identificacion) =>
        (identificacion ?? string.Empty).Trim().ToUpperInvariant();

    private static Animal CrearAnimal(Guid ranchoId, RegistrarAnimalRequest request)
    {
        var animal = new Animal
        {
            Id = Guid.NewGuid(),
            RanchoId = ranchoId,
            // RN-04: todo animal nace Activo; las ventas y muertes se registran como baja (HU-54).
            Estado = EstadoAnimal.Activo,
            FechaRegistro = DateTime.UtcNow,
        };
        CopiarDatos(request, animal);
        return animal;
    }

    private static void CopiarDatos(RegistrarAnimalRequest request, Animal animal)
    {
        animal.Arete = NormalizarIdentificacion(request.Arete);
        animal.Sexo = request.Sexo;
        animal.Raza = request.Raza.Trim();
        animal.Peso = request.Peso;
        animal.Nombre = TextoOpcional(request.Nombre);
        animal.FechaNacimiento = request.FechaNacimiento;
        animal.PesoNacimiento = request.PesoNacimiento;
        animal.Color = TextoOpcional(request.Color);
        animal.Observaciones = TextoOpcional(request.Observaciones);
        // Una hembra nunca queda marcada como castrada.
        animal.Castrado = request.Sexo == SexoAnimal.Macho && request.Castrado;
    }

    private static string? TextoOpcional(string? texto) => string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private async Task<Animal> ObtenerDelRanchoActualAsync(Guid id)
    {
        // RN-16: se busca siempre dentro del rancho del usuario actual, nunca
        // por Id solo — así un animal de otro rancho se ve como "no existe".
        return await _animalRepository.ObtenerPorIdAsync(_currentUser.RanchoId, id)
            ?? throw new RecursoNoEncontradoException("No se encontró el animal.");
    }

    private static bool TieneEventosAsociados(Animal animal) => false;

    private static AnimalResponse ToResponse(Animal animal) =>
        new(
            animal.Id,
            animal.Arete,
            animal.Sexo,
            animal.Raza,
            animal.Peso,
            animal.Estado,
            animal.FechaRegistro,
            animal.Nombre,
            animal.FechaNacimiento,
            animal.PesoNacimiento,
            animal.Color,
            animal.Observaciones,
            animal.Castrado,
            animal.CategoriaAl(Hoy()));
}
