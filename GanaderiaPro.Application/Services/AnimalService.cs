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

    public async Task<AnimalResponse> ObtenerPorIdAsync(Guid id)
    {
        var animal = await ObtenerDelRanchoActualAsync(id);
        return ToResponse(animal);
    }

    public async Task<AnimalResponse> EditarAsync(Guid id, RegistrarAnimalRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Arete))
        {
            throw new ReglaDeNegocioException("El arete es obligatorio.");
        }

        var animal = await ObtenerDelRanchoActualAsync(id);

        // RN-01: el arete es único dentro del rancho (sin contarse a sí mismo).
        var existeArete = await _animalRepository.ExisteAreteAsync(animal.RanchoId, request.Arete, excluirId: id);
        if (existeArete)
        {
            throw new ReglaDeNegocioException($"Ya existe un animal con el arete '{request.Arete}' en este rancho.");
        }

        animal.Arete = request.Arete;
        animal.Sexo = request.Sexo;
        animal.Raza = request.Raza;
        animal.Peso = request.Peso;

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

    private async Task<Animal> ObtenerDelRanchoActualAsync(Guid id)
    {
        // RN-16: se busca siempre dentro del rancho del usuario actual, nunca
        // por Id solo — así un animal de otro rancho se ve como "no existe".
        return await _animalRepository.ObtenerPorIdAsync(_currentUser.RanchoId, id)
            ?? throw new RecursoNoEncontradoException("No se encontró el animal.");
    }

    private static bool TieneEventosAsociados(Animal animal) => false;

    private static AnimalResponse ToResponse(Animal animal) =>
        new(animal.Id, animal.Arete, animal.Sexo, animal.Raza, animal.Peso, animal.Estado, animal.FechaRegistro);
}
