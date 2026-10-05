using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-26: registro de vacunaciones (una o varias a la vez), su historial por
// animal y la corrección de las cargadas por error.
public class VacunacionService : IVacunacionService
{
    private const int MaximoAnimalesPorRegistro = 500;
    private const int CantidadRecientes = 50;
    // Una misma vacuna aplicada hace menos de estos días pide confirmación.
    private const int DiasAplicacionReciente = 30;

    private readonly IVacunacionRepository _vacunacionRepository;
    private readonly IAnimalRepository _animalRepository;
    private readonly ICurrentUserContext _currentUser;
    private readonly IUnitOfWork _unitOfWork;

    public VacunacionService(
        IVacunacionRepository vacunacionRepository,
        IAnimalRepository animalRepository,
        ICurrentUserContext currentUser,
        IUnitOfWork unitOfWork)
    {
        _vacunacionRepository = vacunacionRepository;
        _animalRepository = animalRepository;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
    }

    public async Task<IReadOnlyList<VacunaResponse>> ListarVacunasAsync() =>
        (await _vacunacionRepository.ListarVacunasAsync()).Select(v => new VacunaResponse(v.Id, v.Nombre)).ToList();

    // Revisa, antes de guardar, si algún animal ya recibió esa vacuna el mismo
    // día (bloqueo), la tiene programada a futuro o la recibió hace poco (avisos).
    public async Task<VerificacionVacunacionResponse> VerificarAsync(RegistrarVacunacionRequest request)
    {
        var animales = await ValidarPedidoAsync(request);
        return await VerificarRepetidasAsync(animales, request.VacunaId, request.FechaAplicacion);
    }

    public async Task<IReadOnlyList<VacunacionResponse>> RegistrarAsync(RegistrarVacunacionRequest request)
    {
        var animales = await ValidarPedidoAsync(request);
        var vacuna = (await _vacunacionRepository.ObtenerVacunaAsync(request.VacunaId))!;

        var verificacion = await VerificarRepetidasAsync(animales, vacuna.Id, request.FechaAplicacion);
        if (verificacion.Bloqueos.Count > 0)
        {
            throw new ReglaDeNegocioException(string.Join(" ", verificacion.Bloqueos.Select(b => b.Motivo)));
        }

        if (verificacion.Avisos.Count > 0 && !request.Confirmado)
        {
            throw new ReglaDeNegocioException(
                "Hay animales con esta vacuna programada o aplicada hace poco. Confirmá antes de registrar.");
        }

        return await GuardarAsync(animales, vacuna, request);
    }

    private async Task<List<Animal>> ValidarPedidoAsync(RegistrarVacunacionRequest request)
    {
        var animalIds = request.AnimalIds?.Distinct().ToList() ?? [];
        if (animalIds.Count == 0)
        {
            throw new ReglaDeNegocioException("Elegí al menos un animal.");
        }

        if (animalIds.Count > MaximoAnimalesPorRegistro)
        {
            throw new ReglaDeNegocioException($"Se pueden vacunar hasta {MaximoAnimalesPorRegistro} animales por registro.");
        }

        await ObtenerVacunaAsync(request.VacunaId);
        var error = ValidarDatos(request.Dosis, request.FechaAplicacion, request.FechaProximaDosis, request.Observacion);
        if (error is not null)
        {
            throw new ReglaDeNegocioException(error);
        }

        // RN-16: todos los animales tienen que ser del rancho actual. Se
        // registra todo o nada, para no dejar una vacunación a medias.
        var animales = new List<Animal>();
        foreach (var id in animalIds)
        {
            var animal = await _animalRepository.ObtenerPorIdAsync(_currentUser.RanchoId, id)
                ?? throw new RecursoNoEncontradoException("No se encontró uno de los animales elegidos.");
            ValidarAnimal(animal, request.FechaAplicacion);
            animales.Add(animal);
        }

        return animales;
    }

    private async Task<VerificacionVacunacionResponse> VerificarRepetidasAsync(
        IReadOnlyList<Animal> animales, Guid vacunaId, DateOnly fecha)
    {
        var vacuna = await _vacunacionRepository.ObtenerVacunaAsync(vacunaId);
        var nombre = vacuna?.Nombre ?? "esta vacuna";
        var previas = await _vacunacionRepository.ListarPorAnimalesYVacunaAsync(animales.Select(a => a.Id).ToList(), vacunaId);
        var bloqueos = new List<AvisoVacunacion>();
        var avisos = new List<AvisoVacunacion>();

        foreach (var animal in animales)
        {
            var delAnimal = previas.Where(v => v.AnimalId == animal.Id).ToList();

            if (delAnimal.Any(v => v.FechaAplicacion == fecha))
            {
                bloqueos.Add(new(animal.Id, animal.Arete, $"{animal.Arete} ya recibió {nombre} el {fecha:dd/MM/yyyy}."));
                continue;
            }

            var motivos = new List<string>();

            // La aplicación más reciente anterior a esta fecha: si su próxima
            // dosis todavía no llegó, esta aplicación la adelanta.
            var ultima = delAnimal
                .Where(v => v.FechaAplicacion < fecha)
                .OrderByDescending(v => v.FechaAplicacion)
                .FirstOrDefault();
            if (ultima?.FechaProximaDosis is { } programada && programada > fecha)
            {
                motivos.Add($"tiene {nombre} programada para el {programada:dd/MM/yyyy}");
            }

            if (ultima is not null && fecha.DayNumber - ultima.FechaAplicacion.DayNumber < DiasAplicacionReciente)
            {
                var dias = fecha.DayNumber - ultima.FechaAplicacion.DayNumber;
                var hace = $"hace {dias} {(dias == 1 ? "día" : "días")}";
                motivos.Add(motivos.Count > 0 ? $"la recibió {hace}" : $"recibió {nombre} {hace}");
            }

            if (motivos.Count > 0)
            {
                avisos.Add(new(animal.Id, animal.Arete, $"{animal.Arete} {string.Join(" y ", motivos)}."));
            }
        }

        return new VerificacionVacunacionResponse(bloqueos, avisos);
    }

    private async Task<IReadOnlyList<VacunacionResponse>> GuardarAsync(
        IReadOnlyList<Animal> animales, Vacuna vacuna, RegistrarVacunacionRequest request)
    {
        var vacunaciones = animales.Select(animal => new Vacunacion
        {
            Id = Guid.NewGuid(),
            AnimalId = animal.Id,
            Animal = animal,
            VacunaId = vacuna.Id,
            Vacuna = vacuna,
            VeterinarioId = _currentUser.UsuarioId,
            Dosis = request.Dosis.Trim(),
            FechaAplicacion = request.FechaAplicacion,
            FechaProximaDosis = request.FechaProximaDosis,
            Observacion = TextoOpcional(request.Observacion),
            FechaRegistro = DateTime.UtcNow,
        }).ToList();

        foreach (var vacunacion in vacunaciones)
        {
            _vacunacionRepository.Agregar(vacunacion);
        }

        await _unitOfWork.GuardarCambiosAsync();
        return vacunaciones.Select(ToResponse).ToList();
    }

    public async Task<VacunacionResponse> EditarAsync(Guid id, EditarVacunacionRequest request)
    {
        var vacunacion = await ObtenerDelRanchoAsync(id);
        var vacuna = await ObtenerVacunaAsync(request.VacunaId);

        var error = ValidarDatos(request.Dosis, request.FechaAplicacion, request.FechaProximaDosis, request.Observacion);
        if (error is not null)
        {
            throw new ReglaDeNegocioException(error);
        }

        ValidarAnimal(vacunacion.Animal!, request.FechaAplicacion);

        var mismoDia = (await _vacunacionRepository.ListarPorAnimalesYVacunaAsync([vacunacion.AnimalId], vacuna.Id))
            .Any(v => v.Id != vacunacion.Id && v.FechaAplicacion == request.FechaAplicacion);
        if (mismoDia)
        {
            throw new ReglaDeNegocioException(
                $"{vacunacion.Animal!.Arete} ya recibió {vacuna.Nombre} el {request.FechaAplicacion:dd/MM/yyyy}.");
        }

        vacunacion.VacunaId = vacuna.Id;
        vacunacion.Vacuna = vacuna;
        vacunacion.Dosis = request.Dosis.Trim();
        vacunacion.FechaAplicacion = request.FechaAplicacion;
        vacunacion.FechaProximaDosis = request.FechaProximaDosis;
        vacunacion.Observacion = TextoOpcional(request.Observacion);
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(vacunacion);
    }

    public async Task EliminarAsync(Guid id)
    {
        var vacunacion = await ObtenerDelRanchoAsync(id);
        if (vacunacion.Animal!.Estado != EstadoAnimal.Activo)
        {
            throw new ReglaDeNegocioException("Solo se pueden corregir vacunaciones de animales activos.");
        }

        _vacunacionRepository.Eliminar(vacunacion);
        await _unitOfWork.GuardarCambiosAsync();
    }

    public async Task<IReadOnlyList<VacunacionResponse>> ListarPorAnimalAsync(Guid animalId)
    {
        var animal = await _animalRepository.ObtenerPorIdAsync(_currentUser.RanchoId, animalId)
            ?? throw new RecursoNoEncontradoException("No se encontró el animal.");
        return (await _vacunacionRepository.ListarPorAnimalAsync(animal.Id)).Select(ToResponse).ToList();
    }

    public async Task<IReadOnlyList<VacunacionResponse>> ListarRecientesAsync() =>
        (await _vacunacionRepository.ListarRecientesAsync(_currentUser.RanchoId, CantidadRecientes))
            .Select(ToResponse)
            .ToList();

    private static string? ValidarDatos(string? dosis, DateOnly aplicacion, DateOnly? proximaDosis, string? observacion)
    {
        if (string.IsNullOrWhiteSpace(dosis))
        {
            return "La dosis es obligatoria.";
        }

        if (dosis.Trim().Length > 50)
        {
            return "La dosis puede tener hasta 50 caracteres.";
        }

        // RN-14: no se registran fechas futuras.
        if (aplicacion > FechaRancho.Hoy())
        {
            return "La fecha de aplicación no puede ser futura.";
        }

        if (proximaDosis is { } proxima && proxima < aplicacion)
        {
            return "La próxima dosis no puede ser anterior a la fecha de aplicación.";
        }

        if (observacion?.Trim().Length > 500)
        {
            return "La observación puede tener hasta 500 caracteres.";
        }

        return null;
    }

    private static void ValidarAnimal(Animal animal, DateOnly aplicacion)
    {
        if (animal.Estado != EstadoAnimal.Activo)
        {
            throw new ReglaDeNegocioException($"El animal {animal.Arete} está dado de baja: no se puede vacunar.");
        }

        if (animal.FechaNacimiento is { } nacimiento && aplicacion < nacimiento)
        {
            throw new ReglaDeNegocioException($"La aplicación no puede ser anterior al nacimiento de {animal.Arete}.");
        }
    }

    private async Task<Vacuna> ObtenerVacunaAsync(Guid id) =>
        await _vacunacionRepository.ObtenerVacunaAsync(id)
            ?? throw new ReglaDeNegocioException("Elegí una vacuna de la lista.");

    // RN-16: la vacunación se busca siempre dentro del rancho actual.
    private async Task<Vacunacion> ObtenerDelRanchoAsync(Guid id) =>
        await _vacunacionRepository.ObtenerPorIdAsync(_currentUser.RanchoId, id)
            ?? throw new RecursoNoEncontradoException("No se encontró la vacunación.");

    private static string? TextoOpcional(string? texto) => string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();

    private static VacunacionResponse ToResponse(Vacunacion v) =>
        new(
            v.Id,
            v.AnimalId,
            v.Animal?.Arete ?? string.Empty,
            v.Animal?.Nombre,
            v.VacunaId,
            v.Vacuna?.Nombre ?? string.Empty,
            v.Dosis,
            v.FechaAplicacion,
            v.FechaProximaDosis,
            v.Observacion,
            v.Veterinario?.Nombre ?? string.Empty);
}
