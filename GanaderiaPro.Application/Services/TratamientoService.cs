using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-57: tratamientos veterinarios de un animal.
public class TratamientoService : ITratamientoService
{
    private const int DuracionMaximaDias = 365;

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

    // Del más reciente al más antiguo.
    public async Task<IReadOnlyList<TratamientoResponse>> ListarAsync(Guid animalId)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        var hoy = FechaRancho.Hoy();
        var tratamientos = await _tratamientoRepository.ListarPorAnimalAsync(animal.Id);
        return tratamientos.Select(t => ToResponse(t, t.Veterinario?.Nombre ?? "—", hoy)).ToList();
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
            Motivo = request.Motivo.Trim(),
            Medicamento = request.Medicamento.Trim(),
            Dosis = request.Dosis.Trim(),
            FechaInicio = request.FechaInicio,
            DuracionDias = request.DuracionDias,
            Observacion = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim(),
            FechaRegistro = DateTime.UtcNow,
        };

        _tratamientoRepository.Agregar(tratamiento);
        await _unitOfWork.GuardarCambiosAsync();

        var veterinario = await _usuarioRepository.ObtenerPorIdAsync(_currentUser.UsuarioId);
        return ToResponse(tratamiento, veterinario?.Nombre ?? "—", FechaRancho.Hoy());
    }

    private static string? Validar(Animal animal, RegistrarTratamientoRequest request)
    {
        if (animal.Estado != EstadoAnimal.Activo)
        {
            return "Solo se pueden registrar tratamientos de animales activos.";
        }

        if (string.IsNullOrWhiteSpace(request.Motivo) || request.Motivo.Trim().Length > 200)
        {
            return "El motivo es obligatorio y puede tener hasta 200 caracteres.";
        }

        if (string.IsNullOrWhiteSpace(request.Medicamento) || request.Medicamento.Trim().Length > 150)
        {
            return "El medicamento es obligatorio y puede tener hasta 150 caracteres.";
        }

        if (string.IsNullOrWhiteSpace(request.Dosis) || request.Dosis.Trim().Length > 100)
        {
            return "La dosis es obligatoria y puede tener hasta 100 caracteres.";
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

        if (request.Observacion?.Trim().Length > 500)
        {
            return "La observación puede tener hasta 500 caracteres.";
        }

        return null;
    }

    // RN-16: el animal se busca siempre dentro del rancho del usuario actual.
    private async Task<Animal> ObtenerAnimalDelRanchoAsync(Guid animalId) =>
        await _animalRepository.ObtenerPorIdAsync(_currentUser.RanchoId, animalId)
            ?? throw new RecursoNoEncontradoException("No se encontró el animal.");

    private static TratamientoResponse ToResponse(Tratamiento t, string veterinario, DateOnly hoy) =>
        new(t.Id, t.Motivo, t.Medicamento, t.Dosis, t.FechaInicio, t.DuracionDias, t.FechaFin, t.EnCursoAl(hoy),
            t.Observacion, veterinario);
}
