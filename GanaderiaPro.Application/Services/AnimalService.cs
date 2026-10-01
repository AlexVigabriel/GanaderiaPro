using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

public class AnimalService : IAnimalService
{
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
        if (string.IsNullOrWhiteSpace(request.Arete))
        {
            throw new ReglaDeNegocioException("El arete es obligatorio.");
        }

        var ranchoId = _currentUser.RanchoId;

        // RN-01: el arete es único dentro del rancho, incluso entre animales dados de baja.
        var existeArete = await _animalRepository.ExisteAreteAsync(ranchoId, request.Arete);
        if (existeArete)
        {
            throw new ReglaDeNegocioException($"Ya existe un animal con el arete '{request.Arete}' en este rancho.");
        }

        var animal = new Animal
        {
            Id = Guid.NewGuid(),
            RanchoId = ranchoId,
            Arete = request.Arete,
            Sexo = request.Sexo,
            Raza = request.Raza,
            Peso = request.Peso,
            Estado = EstadoAnimal.Activo,
            FechaRegistro = DateTime.UtcNow
        };

        _animalRepository.Agregar(animal);
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(animal);
    }

    public async Task<IReadOnlyList<AnimalResponse>> BuscarAsync(string? busqueda, EstadoAnimal? estado, SexoAnimal? sexo, string? raza)
    {
        // RN-04: por defecto solo se muestran animales Activos, salvo que se pida un estado explícito.
        var estadoEfectivo = estado ?? EstadoAnimal.Activo;

        var animales = await _animalRepository.BuscarAsync(_currentUser.RanchoId, busqueda, estadoEfectivo, sexo, raza);
        return animales.Select(ToResponse).ToList();
    }

    private static AnimalResponse ToResponse(Animal animal) =>
        new(animal.Id, animal.Arete, animal.Sexo, animal.Raza, animal.Peso, animal.Estado, animal.FechaRegistro);
}
