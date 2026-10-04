using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-55: registro e historial de pesajes de un animal.
public class PesajeService : IPesajeService
{
    private const decimal PesoMaximoKg = 1500;

    private readonly IPesajeRepository _pesajeRepository;
    private readonly IAnimalRepository _animalRepository;
    private readonly ICurrentUserContext _currentUser;
    private readonly IUnitOfWork _unitOfWork;

    public PesajeService(
        IPesajeRepository pesajeRepository,
        IAnimalRepository animalRepository,
        ICurrentUserContext currentUser,
        IUnitOfWork unitOfWork)
    {
        _pesajeRepository = pesajeRepository;
        _animalRepository = animalRepository;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
    }

    public async Task<RegistrarPesajeResponse> RegistrarAsync(Guid animalId, RegistrarPesajeRequest request)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);

        var error = Validar(animal, request);
        if (error is not null)
        {
            throw new ReglaDeNegocioException(error);
        }

        // Un pesaje por día: dos en la misma fecha no se pueden ordenar y
        // suelen ser un error de carga.
        if (await _pesajeRepository.ExisteEnFechaAsync(animal.Id, request.Fecha))
        {
            throw new ReglaDeNegocioException("Ya hay un pesaje registrado en esa fecha para este animal.");
        }

        var pesaje = new Pesaje
        {
            Id = Guid.NewGuid(),
            AnimalId = animal.Id,
            Fecha = request.Fecha,
            Peso = request.Peso,
            Observacion = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim(),
            FechaRegistro = DateTime.UtcNow,
        };

        // El peso actual cambia solo si este pesaje es el más reciente; uno
        // con fecha anterior se suma al historial sin tocarlo.
        var ultimaFecha = await _pesajeRepository.ObtenerUltimaFechaAsync(animal.Id);
        if (ultimaFecha is null || request.Fecha >= ultimaFecha)
        {
            animal.Peso = request.Peso;
        }

        _pesajeRepository.Agregar(pesaje);
        await _unitOfWork.GuardarCambiosAsync();

        return new RegistrarPesajeResponse(ToResponse(pesaje), animal.Peso);
    }

    // Corrige un pesaje cargado con error; el peso actual se recalcula.
    public async Task<RegistrarPesajeResponse> EditarAsync(Guid animalId, Guid pesajeId, RegistrarPesajeRequest request)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        var pesaje = await ObtenerPesajeAsync(animal.Id, pesajeId);

        var error = Validar(animal, request);
        if (error is not null)
        {
            throw new ReglaDeNegocioException(error);
        }

        // Solo si cambia la fecha: corregir el peso de un pesaje no crea un
        // conflicto nuevo (puede haber días repetidos cargados antes de la regla).
        if (request.Fecha != pesaje.Fecha &&
            await _pesajeRepository.ExisteEnFechaAsync(animal.Id, request.Fecha, excluirId: pesaje.Id))
        {
            throw new ReglaDeNegocioException("Ya hay un pesaje registrado en esa fecha para este animal.");
        }

        pesaje.Fecha = request.Fecha;
        pesaje.Peso = request.Peso;
        pesaje.Observacion = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim();

        await RecalcularPesoActualAsync(animal, quitado: null);
        await _unitOfWork.GuardarCambiosAsync();

        return new RegistrarPesajeResponse(ToResponse(pesaje), animal.Peso);
    }

    // Borra un pesaje cargado con error; devuelve el peso actual recalculado.
    public async Task<decimal?> EliminarAsync(Guid animalId, Guid pesajeId)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        var pesaje = await ObtenerPesajeAsync(animal.Id, pesajeId);

        if (animal.Estado != EstadoAnimal.Activo)
        {
            throw new ReglaDeNegocioException("Solo se pueden corregir pesajes de animales activos.");
        }

        _pesajeRepository.Eliminar(pesaje);
        await RecalcularPesoActualAsync(animal, quitado: pesaje.Id);
        await _unitOfWork.GuardarCambiosAsync();

        return animal.Peso;
    }

    // El peso actual es el del pesaje más reciente que quede. Si no queda
    // ninguno, se conserva el último peso conocido.
    private async Task RecalcularPesoActualAsync(Animal animal, Guid? quitado)
    {
        var pesajes = await _pesajeRepository.ListarPorAnimalAsync(animal.Id);
        var masReciente = pesajes
            .Where(p => p.Id != quitado)
            .OrderByDescending(p => p.Fecha)
            .ThenByDescending(p => p.FechaRegistro)
            .FirstOrDefault();

        if (masReciente is not null)
        {
            animal.Peso = masReciente.Peso;
        }
    }

    private async Task<Pesaje> ObtenerPesajeAsync(Guid animalId, Guid pesajeId) =>
        await _pesajeRepository.ObtenerPorIdAsync(animalId, pesajeId)
            ?? throw new RecursoNoEncontradoException("No se encontró el pesaje.");

    public async Task<IReadOnlyList<PesajeResponse>> ListarAsync(Guid animalId)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        var pesajes = await _pesajeRepository.ListarPorAnimalAsync(animal.Id);
        return pesajes.Select(ToResponse).ToList();
    }

    private static string? Validar(Animal animal, RegistrarPesajeRequest request)
    {
        if (animal.Estado != EstadoAnimal.Activo)
        {
            return "Solo se pueden registrar pesajes de animales activos.";
        }

        if (request.Peso <= 0 || request.Peso > PesoMaximoKg)
        {
            return $"El peso debe ser mayor que 0 y de hasta {PesoMaximoKg} kg.";
        }

        // RN-14: no se registran fechas futuras.
        if (request.Fecha > FechaRancho.Hoy())
        {
            return "La fecha del pesaje no puede ser futura.";
        }

        if (animal.FechaNacimiento is { } nacimiento && request.Fecha < nacimiento)
        {
            return "La fecha del pesaje no puede ser anterior al nacimiento.";
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

    private static PesajeResponse ToResponse(Pesaje pesaje) =>
        new(pesaje.Id, pesaje.Fecha, pesaje.Peso, pesaje.Observacion);
}
