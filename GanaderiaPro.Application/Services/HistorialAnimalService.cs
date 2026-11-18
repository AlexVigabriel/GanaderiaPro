using System.Globalization;
using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-22: línea de tiempo del animal con vacunaciones, tratamientos, pesajes,
// preñez/parto y movimientos de corral, del más reciente al más antiguo.
public class HistorialAnimalService : IHistorialAnimalService
{
    private static readonly CultureInfo Cultura = CultureInfo.InvariantCulture;

    private readonly IAnimalRepository _animalRepository;
    private readonly IVacunacionRepository _vacunacionRepository;
    private readonly ITratamientoRepository _tratamientoRepository;
    private readonly IPesajeRepository _pesajeRepository;
    private readonly IPrenezRepository _prenezRepository;
    private readonly IMovimientoCorralRepository _movimientoRepository;
    private readonly IEventoEstadoAnimalRepository _estadoRepository;
    private readonly ICurrentUserContext _currentUser;

    public HistorialAnimalService(
        IAnimalRepository animalRepository,
        IVacunacionRepository vacunacionRepository,
        ITratamientoRepository tratamientoRepository,
        IPesajeRepository pesajeRepository,
        IPrenezRepository prenezRepository,
        IMovimientoCorralRepository movimientoRepository,
        IEventoEstadoAnimalRepository estadoRepository,
        ICurrentUserContext currentUser)
    {
        _animalRepository = animalRepository;
        _vacunacionRepository = vacunacionRepository;
        _tratamientoRepository = tratamientoRepository;
        _pesajeRepository = pesajeRepository;
        _prenezRepository = prenezRepository;
        _movimientoRepository = movimientoRepository;
        _currentUser = currentUser;
        _estadoRepository = estadoRepository;
    }

    public async Task<IReadOnlyList<EventoHistorialResponse>> ListarAsync(Guid animalId)
    {
        // RN-16: solo animales del rancho actual.
        var animal = await _animalRepository.ObtenerPorIdAsync(_currentUser.RanchoId, animalId)
            ?? throw new RecursoNoEncontradoException("No se encontró el animal.");

        var eventos = new List<EventoHistorialResponse>();

        foreach (var v in await _vacunacionRepository.ListarPorAnimalAsync(animal.Id))
        {
            eventos.Add(new(v.FechaAplicacion, "Vacunacion",
                $"{v.Vacuna?.Nombre ?? "Vacuna"} · dosis {v.Dosis}", v.Veterinario?.Nombre, v.FechaRegistro));
        }

        foreach (var t in await _tratamientoRepository.ListarPorAnimalAsync(animal.Id))
        {
            var dias = t.DuracionDias == 1 ? "1 día" : $"{t.DuracionDias} días";
            eventos.Add(new(t.FechaInicio, "Tratamiento",
                $"{t.Motivo} · {t.Medicamento} {t.Dosis}, {dias}", t.Veterinario?.Nombre, t.FechaRegistro));
        }

        foreach (var p in await _pesajeRepository.ListarPorAnimalAsync(animal.Id))
        {
            eventos.Add(new(p.Fecha, "Pesaje", $"{p.Peso.ToString("0.##", Cultura)} kg", p.RegistradoPor?.Nombre, p.FechaRegistro));
        }

        foreach (var p in await _prenezRepository.ListarPorAnimalAsync(animal.Id))
        {
            eventos.Add(new(p.FechaServicio, "Servicio",
                $"Servicio · parto probable el {p.FechaProbableParto:dd/MM/yyyy}", p.RegistradoPor?.Nombre, p.FechaRegistro));
            if (p.FechaParto is { } parto)
            {
                eventos.Add(new(parto, "Parto", "Parto registrado", p.PartoRegistradoPor?.Nombre ?? p.RegistradoPor?.Nombre, p.FechaRegistro));
            }
        }

        foreach (var m in await _movimientoRepository.ListarPorAnimalAsync(animal.Id))
        {
            var descripcion = (m.CorralOrigen, m.CorralDestino) switch
            {
                (null, { } destino) => $"Entró al corral «{destino}»",
                ({ } origen, null) => $"Salió del corral «{origen}»",
                var (origen, destino) => $"Pasó del corral «{origen}» a «{destino}»",
            };
            eventos.Add(new(FechaRancho.DeUtc(m.Fecha), "MovimientoCorral", descripcion, m.Usuario?.Nombre, m.Fecha));
        }

        var cambiosEstado = await _estadoRepository.ListarPorAnimalAsync(animal.Id);
        foreach (var cambio in cambiosEstado)
        {
            var reactivado = cambio.EstadoNuevo == EstadoAnimal.Activo;
            var descripcion = reactivado
                ? $"Animal reactivado (antes: {cambio.EstadoAnterior})."
                : $"Baja registrada: {cambio.EstadoNuevo}.";
            if (!string.IsNullOrWhiteSpace(cambio.Observacion)) descripcion += $" {cambio.Observacion}";
            eventos.Add(new(cambio.FechaEvento, reactivado ? "Reactivacion" : "Baja", descripcion,
                cambio.Usuario?.Nombre, cambio.FechaRegistro));
        }

        // Compatibilidad con bajas antiguas, anteriores al registro de eventos.
        if (animal.FechaBaja is { } fechaBaja && !cambiosEstado.Any(c => c.EstadoNuevo != EstadoAnimal.Activo))
        {
            eventos.Add(new(fechaBaja, "Baja", $"Baja registrada: {animal.Estado}.", null, animal.FechaRegistro));
        }

        return eventos
            .OrderByDescending(e => e.Fecha)
            .ThenByDescending(e => e.FechaRegistro)
            .ToList();
    }
}
