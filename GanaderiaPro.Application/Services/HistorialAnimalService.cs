using System.Globalization;
using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-22: línea de tiempo del animal con vacunaciones, tratamientos, pesajes,
// preñez/parto y movimientos de corral, del más reciente al más antiguo.
// RC-11: también el seguimiento y el fin de cada tratamiento, el diagnóstico de
// preñez y el aborto; cada evento lleva su categoría para filtrar.
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

    public static string NombreResultado(ResultadoTratamiento resultado) => resultado switch
    {
        ResultadoTratamiento.Recuperado => "Recuperado",
        ResultadoTratamiento.SinMejoria => "Sin mejoría",
        _ => "Derivado",
    };

    public static string NombreEvolucion(EvolucionTratamiento evolucion) => evolucion switch
    {
        EvolucionTratamiento.Mejora => "Mejora",
        EvolucionTratamiento.SinCambios => "Sin cambios",
        _ => "Empeora",
    };

    public async Task<IReadOnlyList<EventoHistorialResponse>> ListarAsync(Guid animalId)
    {
        // RN-16: solo animales del rancho actual.
        var animal = await _animalRepository.ObtenerPorIdAsync(_currentUser.RanchoId, animalId)
            ?? throw new RecursoNoEncontradoException("No se encontró el animal.");

        var hoy = FechaRancho.Hoy();
        var eventos = new List<EventoHistorialResponse>();

        foreach (var v in await _vacunacionRepository.ListarPorAnimalAsync(animal.Id))
        {
            eventos.Add(new(v.FechaAplicacion, "Vacunacion", CategoriaEvento.Sanidad,
                $"{v.Vacuna?.Nombre ?? "Vacuna"} · dosis {v.Dosis}", v.Veterinario?.Nombre, v.FechaRegistro));
        }

        foreach (var t in await _tratamientoRepository.ListarPorAnimalAsync(animal.Id))
        {
            var dias = t.DuracionDias == 1 ? "1 día" : $"{t.DuracionDias} días";
            var estado = t.EstadoAl(hoy) switch
            {
                EstadoTratamiento.EnCurso => $"en curso, día {t.DiaAl(hoy)} de {t.DuracionDias}",
                EstadoTratamiento.Finalizado => $"finalizado: {NombreResultado(t.Resultado!.Value)}",
                _ => "terminado sin resultado",
            };
            eventos.Add(new(t.FechaInicio, "Tratamiento", CategoriaEvento.Sanidad,
                $"{t.Diagnostico} · {t.Medicamento} {t.Dosis}, {dias} · {estado}", t.Veterinario?.Nombre, t.FechaRegistro));

            foreach (var s in t.Seguimientos)
            {
                var nota = s.Nota is null ? "" : $" · {s.Nota}";
                eventos.Add(new(s.Fecha, "SeguimientoTratamiento", CategoriaEvento.Sanidad,
                    $"{t.Diagnostico} (día {t.DiaAl(s.Fecha)} de {t.DuracionDias}): {NombreEvolucion(s.Evolucion)}{nota}",
                    s.RegistradoPor?.Nombre, s.FechaRegistro));
            }

            if (t.Resultado is { } resultado && t.FechaFinalizacion is { } fin)
            {
                // Después de los seguimientos del mismo día.
                var registro = t.Seguimientos.Select(s => s.FechaRegistro).Append(t.FechaRegistro).Max().AddTicks(1);
                eventos.Add(new(fin, "FinTratamiento", CategoriaEvento.Sanidad,
                    $"{t.Diagnostico} · resultado: {NombreResultado(resultado)}", t.FinalizadoPor?.Nombre, registro));
            }
        }

        foreach (var p in await _pesajeRepository.ListarPorAnimalAsync(animal.Id))
        {
            eventos.Add(new(p.Fecha, "Pesaje", CategoriaEvento.Pesajes,
                $"{p.Peso.ToString("0.##", Cultura)} kg", p.RegistradoPor?.Nombre, p.FechaRegistro));
        }

        foreach (var p in await _prenezRepository.ListarPorAnimalAsync(animal.Id))
        {
            var quien = p.RegistradoPor?.Nombre;
            eventos.Add(new(p.FechaServicio, "Servicio", CategoriaEvento.Reproduccion,
                $"Servicio · parto probable el {p.FechaProbableParto:dd/MM/yyyy}", quien, p.FechaRegistro));
            if (p.Diagnostico is { } diagnostico && p.FechaDiagnostico is { } fechaDiagnostico)
            {
                eventos.Add(new(fechaDiagnostico, "DiagnosticoPrenez", CategoriaEvento.Reproduccion,
                    diagnostico == DiagnosticoPrenez.Confirmada ? "Preñez confirmada" : "Vacía: la preñez se cerró",
                    quien, p.FechaRegistro.AddTicks(1)));
            }
            if (p.FechaAborto is { } aborto)
            {
                eventos.Add(new(aborto, "Aborto", CategoriaEvento.Reproduccion, "Aborto: la preñez se cerró",
                    quien, p.FechaRegistro.AddTicks(2)));
            }
            if (p.FechaParto is { } parto)
            {
                eventos.Add(new(parto, "Parto", CategoriaEvento.Reproduccion, "Parto registrado",
                    p.PartoRegistradoPor?.Nombre ?? quien, p.FechaRegistro.AddTicks(2)));
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
            eventos.Add(new(FechaRancho.DeUtc(m.Fecha), "MovimientoCorral", CategoriaEvento.Corrales, descripcion,
                m.Usuario?.Nombre, m.Fecha));
        }

        var cambiosEstado = await _estadoRepository.ListarPorAnimalAsync(animal.Id);
        foreach (var cambio in cambiosEstado)
        {
            var reactivado = cambio.EstadoNuevo == EstadoAnimal.Activo;
            var descripcion = reactivado
                ? $"Animal reactivado (antes: {cambio.EstadoAnterior})."
                : $"Baja registrada: {cambio.EstadoNuevo}.";
            if (!string.IsNullOrWhiteSpace(cambio.Observacion)) descripcion += $" {cambio.Observacion}";
            eventos.Add(new(cambio.FechaEvento, reactivado ? "Reactivacion" : "Baja", CategoriaEvento.Estado, descripcion,
                cambio.Usuario?.Nombre, cambio.FechaRegistro));
        }

        // Compatibilidad con bajas antiguas, anteriores al registro de eventos.
        if (animal.FechaBaja is { } fechaBaja && !cambiosEstado.Any(c => c.EstadoNuevo != EstadoAnimal.Activo))
        {
            eventos.Add(new(fechaBaja, "Baja", CategoriaEvento.Estado, $"Baja registrada: {animal.Estado}.", null,
                animal.FechaRegistro));
        }

        return eventos
            .OrderByDescending(e => e.Fecha)
            .ThenByDescending(e => e.FechaRegistro)
            .ToList();
    }
}
