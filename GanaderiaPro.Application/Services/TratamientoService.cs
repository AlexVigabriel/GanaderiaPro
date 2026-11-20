using System.Text.RegularExpressions;
using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-57: tratamientos veterinarios de un animal. RC-08: diagnóstico y dosis con
// unidad. RC-09: seguimiento diario y finalización con resultado.
public partial class TratamientoService : ITratamientoService
{
    private const int DuracionMaximaDias = 365;
    private const int LargoDiagnostico = 100;
    private const int LargoObservacion = 300;
    private const int TerminadosMostrados = 50;

    public const string UnidadesDosis = "ml, mg, g, cc, UI o comprimidos";

    private readonly ITratamientoRepository _tratamientoRepository;
    private readonly IAnimalRepository _animalRepository;
    private readonly IUsuarioRepository _usuarioRepository;
    private readonly ICurrentUserContext _currentUser;
    private readonly IUnitOfWork _unitOfWork;

    public TratamientoService(
        ITratamientoRepository tratamientoRepository,
        IAnimalRepository animalRepository,
        IUsuarioRepository usuarioRepository,
        ICurrentUserContext currentUser,
        IUnitOfWork unitOfWork)
    {
        _tratamientoRepository = tratamientoRepository;
        _animalRepository = animalRepository;
        _usuarioRepository = usuarioRepository;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
    }

    // RC-08: «5» no dice cuánto; «5 ml» sí.
    public static bool DosisValida(string? dosis) => dosis is not null && DosisConUnidad().IsMatch(dosis.Trim());

    // Del más reciente al más antiguo.
    public async Task<IReadOnlyList<TratamientoResponse>> ListarAsync(Guid animalId)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        var hoy = FechaRancho.Hoy();
        var tratamientos = await _tratamientoRepository.ListarPorAnimalAsync(animal.Id);
        return tratamientos.Select(t => ToResponse(t, animal, hoy)).ToList();
    }

    // RC-09: tratamientos del rancho, en curso o terminados (los últimos 50).
    public async Task<IReadOnlyList<TratamientoResponse>> ListarDelRanchoAsync(bool terminados)
    {
        var hoy = FechaRancho.Hoy();
        var todos = await _tratamientoRepository.ListarDelRanchoAsync(_currentUser.RanchoId);
        var elegidos = terminados
            ? todos.Where(t => t.EstadoAl(hoy) != EstadoTratamiento.EnCurso)
                .OrderByDescending(t => t.FechaFinalizacion ?? t.FechaFin)
                .Take(TerminadosMostrados)
            : todos.Where(t => t.EstadoAl(hoy) == EstadoTratamiento.EnCurso)
                .OrderBy(t => t.FechaFin);
        return elegidos.Select(t => ToResponse(t, t.Animal!, hoy)).ToList();
    }

    public async Task<TratamientoResponse> RegistrarAsync(Guid animalId, RegistrarTratamientoRequest request)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);

        var error = Validar(animal, request);
        if (error is not null)
        {
            throw new ReglaDeNegocioException(error);
        }

        var tratamiento = new Tratamiento
        {
            Id = Guid.NewGuid(),
            AnimalId = animal.Id,
            VeterinarioId = _currentUser.UsuarioId,
            Diagnostico = request.Diagnostico.Trim(),
            Medicamento = request.Medicamento.Trim(),
            Dosis = NormalizarDosis(request.Dosis),
            FechaInicio = request.FechaInicio,
            DuracionDias = request.DuracionDias,
            Observacion = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim(),
            FechaRegistro = DateTime.UtcNow,
        };

        _tratamientoRepository.Agregar(tratamiento);
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(tratamiento, animal, FechaRancho.Hoy(), await NombreUsuarioActualAsync());
    }

    // RC-09: un seguimiento por día, entre el inicio y hoy (RN-14), sin pasar el último día.
    public async Task<TratamientoResponse> RegistrarSeguimientoAsync(
        Guid animalId, Guid tratamientoId, RegistrarSeguimientoRequest request)
    {
        var (animal, tratamiento) = await ObtenerTratamientoAsync(animalId, tratamientoId);
        var hoy = FechaRancho.Hoy();

        if (tratamiento.Finalizado)
        {
            throw new ReglaDeNegocioException("El tratamiento ya está finalizado: no admite más seguimientos.");
        }

        if (!Enum.IsDefined(request.Evolucion))
        {
            throw new ReglaDeNegocioException("Elegí la evolución: Mejora, Sin cambios o Empeora.");
        }

        if (request.Fecha > hoy)
        {
            throw new ReglaDeNegocioException("La fecha del seguimiento no puede ser futura.");
        }

        if (request.Fecha < tratamiento.FechaInicio)
        {
            throw new ReglaDeNegocioException("La fecha del seguimiento no puede ser anterior al inicio del tratamiento.");
        }

        if (request.Fecha > tratamiento.FechaFin)
        {
            throw new ReglaDeNegocioException(
                $"La fecha del seguimiento no puede ser posterior al último día del tratamiento ({tratamiento.FechaFin:dd/MM/yyyy}).");
        }

        if (tratamiento.Seguimientos.Any(s => s.Fecha == request.Fecha))
        {
            throw new ReglaDeNegocioException($"Ya hay un seguimiento registrado el {request.Fecha:dd/MM/yyyy}.");
        }

        // RC-07: la nota tiene que describir algo.
        if (TextoDescriptivo.Validar(request.Nota, LargoObservacion, "La nota") is { } errorNota)
        {
            throw new ReglaDeNegocioException(errorNota);
        }

        var seguimiento = new SeguimientoTratamiento
        {
            Id = Guid.NewGuid(),
            TratamientoId = tratamiento.Id,
            Fecha = request.Fecha,
            Evolucion = request.Evolucion,
            Nota = string.IsNullOrWhiteSpace(request.Nota) ? null : request.Nota.Trim(),
            RegistradoPorId = _currentUser.UsuarioId,
            FechaRegistro = DateTime.UtcNow,
        };

        _tratamientoRepository.AgregarSeguimiento(seguimiento);
        tratamiento.Seguimientos.Add(seguimiento);
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(tratamiento, animal, hoy, await NombreUsuarioActualAsync());
    }

    // RC-09: se puede finalizar antes del último día, o cargar el resultado después.
    public async Task<TratamientoResponse> FinalizarAsync(Guid animalId, Guid tratamientoId, FinalizarTratamientoRequest request)
    {
        var (animal, tratamiento) = await ObtenerTratamientoAsync(animalId, tratamientoId);
        var hoy = FechaRancho.Hoy();

        if (tratamiento.Finalizado)
        {
            throw new ReglaDeNegocioException("Este tratamiento ya está finalizado.");
        }

        if (!Enum.IsDefined(request.Resultado))
        {
            throw new ReglaDeNegocioException("Elegí el resultado: Recuperado, Sin mejoría o Derivado.");
        }

        if (request.Fecha > hoy)
        {
            throw new ReglaDeNegocioException("La fecha de finalización no puede ser futura.");
        }

        if (request.Fecha < tratamiento.FechaInicio)
        {
            throw new ReglaDeNegocioException("La fecha de finalización no puede ser anterior al inicio del tratamiento.");
        }

        var ultimoSeguimiento = tratamiento.Seguimientos.Select(s => (DateOnly?)s.Fecha).Max();
        if (ultimoSeguimiento is { } ultimo && request.Fecha < ultimo)
        {
            throw new ReglaDeNegocioException(
                $"La fecha de finalización no puede ser anterior al último seguimiento ({ultimo:dd/MM/yyyy}).");
        }

        tratamiento.Resultado = request.Resultado;
        tratamiento.FechaFinalizacion = request.Fecha;
        tratamiento.FinalizadoPorId = _currentUser.UsuarioId;
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(tratamiento, animal, hoy, await NombreUsuarioActualAsync());
    }

    private static string? Validar(Animal animal, RegistrarTratamientoRequest request)
    {
        if (animal.Estado != EstadoAnimal.Activo)
        {
            return "Solo se pueden registrar tratamientos de animales activos.";
        }

        if (string.IsNullOrWhiteSpace(request.Diagnostico) || request.Diagnostico.Trim().Length > LargoDiagnostico)
        {
            return $"El diagnóstico es obligatorio y puede tener hasta {LargoDiagnostico} caracteres.";
        }

        if (string.IsNullOrWhiteSpace(request.Medicamento) || request.Medicamento.Trim().Length > 150)
        {
            return "El medicamento es obligatorio y puede tener hasta 150 caracteres.";
        }

        if (!DosisValida(request.Dosis))
        {
            return $"La dosis debe tener una cantidad y una unidad ({UnidadesDosis}), por ejemplo «5 ml».";
        }

        if (request.DuracionDias < 1 || request.DuracionDias > DuracionMaximaDias)
        {
            return $"La duración debe ser de 1 a {DuracionMaximaDias} días.";
        }

        // RN-14: no se registran fechas futuras.
        if (request.FechaInicio > FechaRancho.Hoy())
        {
            return "La fecha de inicio no puede ser futura.";
        }

        if (animal.FechaNacimiento is { } nacimiento && request.FechaInicio < nacimiento)
        {
            return "La fecha de inicio no puede ser anterior al nacimiento.";
        }

        // RC-07: la observación tiene que describir algo, no ser solo un número.
        if (TextoDescriptivo.Validar(request.Observacion, LargoObservacion) is { } errorObservacion)
        {
            return errorObservacion;
        }

        return null;
    }

    // «5ML» → «5 ml»; la unidad internacional se escribe «UI».
    private static string NormalizarDosis(string dosis)
    {
        var m = DosisConUnidad().Match(dosis.Trim());
        var unidad = m.Groups["unidad"].Value.ToLowerInvariant();
        unidad = unidad == "ui" ? "UI" : unidad;
        return $"{m.Groups["cantidad"].Value} {unidad}";
    }

    // RN-16: el animal se busca siempre dentro del rancho del usuario actual.
    private async Task<Animal> ObtenerAnimalDelRanchoAsync(Guid animalId) =>
        await _animalRepository.ObtenerPorIdAsync(_currentUser.RanchoId, animalId)
            ?? throw new RecursoNoEncontradoException("No se encontró el animal.");

    private async Task<(Animal, Tratamiento)> ObtenerTratamientoAsync(Guid animalId, Guid tratamientoId)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        if (animal.Estado != EstadoAnimal.Activo)
        {
            throw new ReglaDeNegocioException("Solo se pueden modificar tratamientos de animales activos.");
        }

        var tratamiento = await _tratamientoRepository.ObtenerPorIdAsync(animal.Id, tratamientoId)
            ?? throw new RecursoNoEncontradoException("No se encontró el tratamiento.");
        return (animal, tratamiento);
    }

    private async Task<string> NombreUsuarioActualAsync() =>
        (await _usuarioRepository.ObtenerPorIdAsync(_currentUser.UsuarioId))?.Nombre ?? "—";

    // nombreActual: nombre del usuario actual, para lo que se acaba de guardar
    // (todavía sin el usuario cargado).
    private TratamientoResponse ToResponse(Tratamiento t, Animal animal, DateOnly hoy, string? nombreActual = null)
    {
        string Nombre(Usuario? usuario, Guid id) =>
            usuario?.Nombre ?? (id == _currentUser.UsuarioId && nombreActual is not null ? nombreActual : "—");

        var seguimientos = t.Seguimientos
            .OrderBy(s => s.Fecha)
            .Select(s => new SeguimientoResponse(s.Id, s.Fecha, s.Evolucion, s.Nota, Nombre(s.RegistradoPor, s.RegistradoPorId)))
            .ToList();

        return new(t.Id, animal.Id, animal.Arete, animal.Nombre, t.Diagnostico, t.Medicamento, t.Dosis, t.FechaInicio,
            t.DuracionDias, t.FechaFin, t.EnCursoAl(hoy), t.EstadoAl(hoy), t.DiaAl(hoy), t.Resultado, t.FechaFinalizacion,
            t.Observacion, Nombre(t.Veterinario, t.VeterinarioId), seguimientos);
    }

    [GeneratedRegex(@"^(?<cantidad>\d+(?:[.,]\d+)?)\s*(?<unidad>ml|mg|g|cc|ui|comprimidos?)$", RegexOptions.IgnoreCase)]
    private static partial Regex DosisConUnidad();
}
