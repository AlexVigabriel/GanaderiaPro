using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-56: preñez y parto de las hembras (RN-10).
public class PrenezService : IPrenezService
{
    private readonly IPrenezRepository _prenezRepository;
    private readonly IAnimalRepository _animalRepository;
    private readonly ICurrentUserContext _currentUser;
    private readonly IUnitOfWork _unitOfWork;

    public PrenezService(
        IPrenezRepository prenezRepository,
        IAnimalRepository animalRepository,
        ICurrentUserContext currentUser,
        IUnitOfWork unitOfWork)
    {
        _prenezRepository = prenezRepository;
        _animalRepository = animalRepository;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
    }

    // De la más reciente a la más antigua.
    public async Task<IReadOnlyList<PrenezResponse>> ListarAsync(Guid animalId)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        var preneces = await _prenezRepository.ListarPorAnimalAsync(animal.Id);
        return preneces.Select(ToResponse).ToList();
    }

    public async Task<PrenezResponse> RegistrarServicioAsync(Guid animalId, RegistrarServicioRequest request)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        ValidarHembraActiva(animal);

        // RN-14: no se registran fechas futuras.
        if (request.FechaServicio > FechaRancho.Hoy())
        {
            throw new ReglaDeNegocioException("La fecha de servicio no puede ser futura.");
        }

        if (animal.FechaNacimiento is { } nacimiento && request.FechaServicio < nacimiento)
        {
            throw new ReglaDeNegocioException("La fecha de servicio no puede ser anterior al nacimiento.");
        }

        if (request.Observacion?.Trim().Length > 500)
        {
            throw new ReglaDeNegocioException("La observación puede tener hasta 500 caracteres.");
        }

        var anteriores = await _prenezRepository.ListarPorAnimalAsync(animal.Id);
        if (anteriores.Any(p => p.Abierta))
        {
            throw new ReglaDeNegocioException(
                "Esta hembra ya tiene una preñez abierta: registrá el parto antes de un nuevo servicio.");
        }

        var ultimoParto = anteriores.Max(p => p.FechaParto);
        if (ultimoParto is not null && request.FechaServicio < ultimoParto)
        {
            throw new ReglaDeNegocioException("La fecha de servicio no puede ser anterior al último parto.");
        }

        var prenez = new Prenez
        {
            Id = Guid.NewGuid(),
            AnimalId = animal.Id,
            FechaServicio = request.FechaServicio,
            FechaProbableParto = Prenez.CalcularFechaProbableParto(request.FechaServicio),
            Observacion = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim(),
            FechaRegistro = DateTime.UtcNow,
        };

        _prenezRepository.Agregar(prenez);
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(prenez);
    }

    // Registrar el parto cierra la preñez: deja de contarse como próxima a parir.
    public async Task<PrenezResponse> RegistrarPartoAsync(Guid animalId, Guid prenezId, RegistrarPartoRequest request)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        ValidarHembraActiva(animal);

        var prenez = await _prenezRepository.ObtenerPorIdAsync(animal.Id, prenezId)
            ?? throw new RecursoNoEncontradoException("No se encontró la preñez.");

        if (!prenez.Abierta)
        {
            throw new ReglaDeNegocioException("Esta preñez ya tiene el parto registrado.");
        }

        if (request.FechaParto > FechaRancho.Hoy())
        {
            throw new ReglaDeNegocioException("La fecha del parto no puede ser futura.");
        }

        if (request.FechaParto < prenez.FechaServicio)
        {
            throw new ReglaDeNegocioException("La fecha del parto no puede ser anterior al servicio.");
        }

        prenez.FechaParto = request.FechaParto;
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(prenez);
    }

    // RN-10: «próxima a parir» = parto probable dentro de los próximos días.
    // También incluye los partos probables ya vencidos que no se registraron.
    public async Task<IReadOnlyList<ProximaAParirResponse>> ListarProximasAParirAsync(int dias = 30)
    {
        var hoy = FechaRancho.Hoy();
        var preneces = await _prenezRepository.ListarAbiertasConPartoHastaAsync(_currentUser.RanchoId, hoy.AddDays(dias));
        return preneces
            .Select(p => new ProximaAParirResponse(
                p.AnimalId,
                p.Animal!.Arete,
                p.Animal.Nombre,
                p.FechaProbableParto,
                p.FechaProbableParto.DayNumber - hoy.DayNumber))
            .ToList();
    }

    private static void ValidarHembraActiva(Animal animal)
    {
        if (animal.Sexo != SexoAnimal.Hembra)
        {
            throw new ReglaDeNegocioException("Solo se puede registrar la preñez de una hembra.");
        }

        if (animal.Estado != EstadoAnimal.Activo)
        {
            throw new ReglaDeNegocioException("Solo se puede registrar la preñez de animales activos.");
        }
    }

    // RN-16: el animal se busca siempre dentro del rancho del usuario actual.
    private async Task<Animal> ObtenerAnimalDelRanchoAsync(Guid animalId) =>
        await _animalRepository.ObtenerPorIdAsync(_currentUser.RanchoId, animalId)
            ?? throw new RecursoNoEncontradoException("No se encontró el animal.");

    private static PrenezResponse ToResponse(Prenez p) =>
        new(p.Id, p.FechaServicio, p.FechaProbableParto, p.FechaParto, p.Abierta, p.Observacion);
}
