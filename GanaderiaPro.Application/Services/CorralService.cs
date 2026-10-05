using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-23 y HU-24: corrales del rancho, su capacidad y su ocupación.
public class CorralService : ICorralService
{
    private const int LargoMaximoNombre = 60;
    private const int CapacidadMaxima = 10000;

    private readonly ICorralRepository _corralRepository;
    private readonly IAnimalRepository _animalRepository;
    private readonly ICurrentUserContext _currentUser;
    private readonly IUnitOfWork _unitOfWork;

    public CorralService(
        ICorralRepository corralRepository,
        IAnimalRepository animalRepository,
        ICurrentUserContext currentUser,
        IUnitOfWork unitOfWork)
    {
        _corralRepository = corralRepository;
        _animalRepository = animalRepository;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
    }

    public async Task<CorralResponse> CrearAsync(CrearCorralRequest request)
    {
        var ranchoId = _currentUser.RanchoId;
        var nombre = await ValidarNombreYCapacidadAsync(ranchoId, request.Nombre, request.Capacidad, excluirId: null);

        // RN-07: la asignación inicial no puede pasar la capacidad.
        var animalIds = request.AnimalIds?.Distinct().ToList() ?? [];
        if (animalIds.Count > request.Capacidad)
        {
            throw new ReglaDeNegocioException(
                $"La capacidad es {request.Capacidad}: quedan {request.Capacidad} lugares y elegiste {animalIds.Count} animales.");
        }

        var corral = new Corral
        {
            Id = Guid.NewGuid(),
            RanchoId = ranchoId,
            Nombre = nombre,
            Capacidad = request.Capacidad,
            Activo = true,
            FechaCreacion = DateTime.UtcNow,
        };

        // RN-16: solo animales del rancho actual. Un animal está en un solo
        // corral: si estaba en otro, se mueve a este.
        foreach (var id in animalIds)
        {
            var animal = await _animalRepository.ObtenerPorIdAsync(ranchoId, id)
                ?? throw new RecursoNoEncontradoException("No se encontró uno de los animales elegidos.");
            if (animal.Estado != EstadoAnimal.Activo)
            {
                throw new ReglaDeNegocioException($"El animal {animal.Arete} está dado de baja: no se puede asignar a un corral.");
            }

            animal.CorralId = corral.Id;
        }

        _corralRepository.Agregar(corral);
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(corral, animalIds.Count);
    }

    public async Task<IReadOnlyList<CorralResponse>> ListarAsync(bool incluirInactivos = false)
    {
        var ranchoId = _currentUser.RanchoId;
        var corrales = await _corralRepository.ListarAsync(ranchoId, incluirInactivos);
        var conteos = await _corralRepository.ContarAnimalesActivosAsync(ranchoId);

        return corrales
            .Select(c => ToResponse(c, conteos.TryGetValue(c.Id, out var cantidad) ? cantidad : 0))
            .ToList();
    }

    public async Task<CorralResponse> EditarAsync(Guid id, EditarCorralRequest request)
    {
        var corral = await ObtenerDelRanchoAsync(id);
        var nombre = await ValidarNombreYCapacidadAsync(corral.RanchoId, request.Nombre, request.Capacidad, excluirId: corral.Id);
        var ocupados = (await _corralRepository.ListarAnimalesActivosAsync(corral.Id)).Count;

        // RN-07 también al achicar el corral.
        if (request.Capacidad < ocupados)
        {
            throw new ReglaDeNegocioException(
                $"El corral tiene {ocupados} animales: la capacidad no puede ser menor que {ocupados}.");
        }

        corral.Nombre = nombre;
        corral.Capacidad = request.Capacidad;
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(corral, ocupados);
    }

    // RN-08: solo se desactiva un corral vacío. Desactivar no lo borra, así
    // que su historial se conserva.
    public async Task<CorralResponse> CambiarEstadoAsync(Guid id, bool activo)
    {
        var corral = await ObtenerDelRanchoAsync(id);
        var ocupados = (await _corralRepository.ListarAnimalesActivosAsync(corral.Id)).Count;

        if (!activo && ocupados > 0)
        {
            throw new ReglaDeNegocioException(
                ocupados == 1
                    ? "El corral tiene 1 animal: reasignalo antes de desactivarlo."
                    : $"El corral tiene {ocupados} animales: reasignalos antes de desactivarlo.");
        }

        corral.Activo = activo;
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(corral, ocupados);
    }

    // Cambia el corral de un animal, o lo saca de su corral con corralId null.
    // Respeta la capacidad del corral de destino (RN-07).
    public async Task AsignarAnimalAsync(Guid animalId, Guid? corralId)
    {
        var ranchoId = _currentUser.RanchoId;
        var animal = await _animalRepository.ObtenerPorIdAsync(ranchoId, animalId)
            ?? throw new RecursoNoEncontradoException("No se encontró el animal.");

        if (animal.Estado != EstadoAnimal.Activo)
        {
            throw new ReglaDeNegocioException($"El animal {animal.Arete} está dado de baja: no se puede mover de corral.");
        }

        if (corralId is { } id && id != animal.CorralId)
        {
            var corral = await ObtenerDelRanchoAsync(id);
            if (!corral.Activo)
            {
                throw new ReglaDeNegocioException($"El corral «{corral.Nombre}» está desactivado.");
            }

            var ocupados = (await _corralRepository.ListarAnimalesActivosAsync(corral.Id)).Count;
            if (ocupados >= corral.Capacidad)
            {
                throw new ReglaDeNegocioException($"El corral «{corral.Nombre}» está lleno ({ocupados}/{corral.Capacidad}).");
            }
        }

        animal.CorralId = corralId;
        await _unitOfWork.GuardarCambiosAsync();
    }

    private async Task<string> ValidarNombreYCapacidadAsync(Guid ranchoId, string? nombre, int capacidad, Guid? excluirId)
    {
        var limpio = nombre?.Trim() ?? string.Empty;
        if (limpio.Length == 0)
        {
            throw new ReglaDeNegocioException("El nombre del corral es obligatorio.");
        }

        if (limpio.Length > LargoMaximoNombre)
        {
            throw new ReglaDeNegocioException($"El nombre puede tener hasta {LargoMaximoNombre} caracteres.");
        }

        if (capacidad < 1 || capacidad > CapacidadMaxima)
        {
            throw new ReglaDeNegocioException($"La capacidad debe ser un número entero entre 1 y {CapacidadMaxima}.");
        }

        // RN-06: el nombre no se repite dentro del rancho.
        if (await _corralRepository.ExisteNombreAsync(ranchoId, limpio, excluirId))
        {
            throw new ReglaDeNegocioException("Ya existe un corral con ese nombre.");
        }

        return limpio;
    }

    // RN-16: el corral se busca siempre dentro del rancho actual.
    private async Task<Corral> ObtenerDelRanchoAsync(Guid id) =>
        await _corralRepository.ObtenerPorIdAsync(_currentUser.RanchoId, id)
            ?? throw new RecursoNoEncontradoException("No se encontró el corral.");

    private static CorralResponse ToResponse(Corral corral, int animales) =>
        new(
            corral.Id,
            corral.Nombre,
            corral.Capacidad,
            corral.Activo,
            animales,
            corral.Capacidad == 0 ? 0 : (int)Math.Round(animales * 100.0 / corral.Capacidad));
}
