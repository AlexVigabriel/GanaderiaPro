using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Eventos;

namespace GanaderiaPro.Application.Services;

// HU-40 (patrón Observer): avisa el evento a todos los observadores
// registrados. Para sumar otro canal (por ejemplo, correo) se agrega un
// observador; no hay que tocar a quien publica (OCP).
public class PublicadorEventos : IPublicadorEventos
{
    private readonly IEnumerable<IObservadorEventos> _observadores;

    public PublicadorEventos(IEnumerable<IObservadorEventos> observadores)
    {
        _observadores = observadores;
    }

    public async Task PublicarAsync(IEventoRancho evento)
    {
        foreach (var observador in _observadores)
        {
            await observador.ManejarAsync(evento);
        }
    }
}

// HU-40: observador que convierte cada evento en notificaciones para los
// responsables. Cada usuario recibe una sola vez la alerta de un mismo hecho.
public class NotificadorAlertas : IObservadorEventos
{
    private readonly INotificacionRepository _notificacionRepository;
    private readonly IUsuarioRepository _usuarioRepository;
    private readonly IUnitOfWork _unitOfWork;

    public NotificadorAlertas(
        INotificacionRepository notificacionRepository,
        IUsuarioRepository usuarioRepository,
        IUnitOfWork unitOfWork)
    {
        _notificacionRepository = notificacionRepository;
        _usuarioRepository = usuarioRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task ManejarAsync(IEventoRancho evento)
    {
        var alerta = Describir(evento);
        if (alerta is null)
        {
            return;
        }

        var usuarios = await _usuarioRepository.ListarActivosAsync(evento.RanchoId);
        var destinatarios = usuarios.Where(u => alerta.Roles.Contains(u.Rol)).ToList();

        // RN-12: si no hay ningún colaborador con ese rol, el responsable es el propietario.
        if (!destinatarios.Any(u => u.Rol != RolUsuario.Propietario))
        {
            destinatarios = usuarios.Where(u => u.Rol == RolUsuario.Propietario).ToList();
        }

        var agregadas = 0;
        foreach (var usuario in destinatarios)
        {
            if (await _notificacionRepository.ExisteAsync(usuario.Id, alerta.Clave))
            {
                continue;
            }

            _notificacionRepository.Agregar(new Notificacion
            {
                Id = Guid.NewGuid(),
                RanchoId = evento.RanchoId,
                UsuarioId = usuario.Id,
                Tipo = alerta.Tipo,
                Mensaje = alerta.Mensaje,
                ReferenciaTipo = alerta.ReferenciaTipo,
                ReferenciaId = alerta.ReferenciaId,
                Clave = alerta.Clave,
                Fecha = DateTime.UtcNow,
            });
            agregadas++;
        }

        if (agregadas > 0)
        {
            await _unitOfWork.GuardarCambiosAsync();
        }
    }

    private sealed record Alerta(
        TipoNotificacion Tipo,
        string Mensaje,
        string ReferenciaTipo,
        Guid ReferenciaId,
        string Clave,
        IReadOnlySet<RolUsuario> Roles);

    private static Alerta? Describir(IEventoRancho evento)
    {
        var hoy = FechaRancho.Hoy();
        return evento switch
        {
            VacunaPendienteDetectada v => new Alerta(
                TipoNotificacion.VacunaPendiente,
                $"{v.Arete}: la próxima dosis de {v.Vacuna} {(v.FechaProximaDosis < hoy ? "venció" : "vence")} el {v.FechaProximaDosis:dd/MM/yyyy}.",
                "Animal",
                v.AnimalId,
                $"vacuna:{v.VacunacionId}",
                new HashSet<RolUsuario> { RolUsuario.Veterinario, RolUsuario.Propietario }),
            CorralLleno c => new Alerta(
                TipoNotificacion.CorralLleno,
                $"El corral «{c.Nombre}» está lleno ({c.Capacidad}/{c.Capacidad}).",
                "Corral",
                c.CorralId,
                // Una vez por día: si se vacía y se vuelve a llenar otro día, avisa de nuevo.
                $"corral:{c.CorralId}:{hoy:yyyy-MM-dd}",
                new HashSet<RolUsuario> { RolUsuario.EncargadoCorrales }),
            PartoProximo p => new Alerta(
                TipoNotificacion.PartoProximo,
                $"{p.Arete}: parto probable el {p.FechaProbableParto:dd/MM/yyyy}.",
                "Animal",
                p.AnimalId,
                $"parto:{p.PrenezId}",
                new HashSet<RolUsuario> { RolUsuario.Veterinario }),
            _ => null,
        };
    }
}

// HU-40: las vacunas pendientes y los partos próximos dependen del paso de
// los días, así que se revisan cuando un usuario consulta sus notificaciones.
public class RevisorAlertas : IRevisorAlertas
{
    public const int DiasAvisoVacuna = 7;
    public const int DiasAvisoParto = 15;

    private readonly IVacunacionRepository _vacunacionRepository;
    private readonly IPrenezRepository _prenezRepository;
    private readonly IPublicadorEventos _publicador;

    public RevisorAlertas(
        IVacunacionRepository vacunacionRepository,
        IPrenezRepository prenezRepository,
        IPublicadorEventos publicador)
    {
        _vacunacionRepository = vacunacionRepository;
        _prenezRepository = prenezRepository;
        _publicador = publicador;
    }

    public async Task RevisarAsync(Guid ranchoId)
    {
        var hoy = FechaRancho.Hoy();

        // RN-09: vencidas o que vencen dentro de los próximos 7 días.
        var pendientes = PendientesSanidad.Calcular(await _vacunacionRepository.ListarDeActivosAsync(ranchoId))
            .Where(p => p.FechaProximaDosis <= hoy.AddDays(DiasAvisoVacuna));
        foreach (var p in pendientes)
        {
            await _publicador.PublicarAsync(
                new VacunaPendienteDetectada(ranchoId, p.VacunacionId, p.AnimalId, p.Arete, p.Vacuna, p.FechaProximaDosis));
        }

        foreach (var p in await _prenezRepository.ListarAbiertasConPartoHastaAsync(ranchoId, hoy.AddDays(DiasAvisoParto)))
        {
            await _publicador.PublicarAsync(
                new PartoProximo(ranchoId, p.Id, p.AnimalId, p.Animal?.Arete ?? string.Empty, p.FechaProbableParto));
        }
    }
}

// HU-40 y HU-41: notificaciones del usuario actual. Cada uno ve y marca
// solo las suyas.
public class NotificacionService : INotificacionService
{
    // Las más recientes; las anteriores quedan guardadas pero no se listan.
    public const int MaximoListado = 100;

    private readonly INotificacionRepository _notificacionRepository;
    private readonly IRevisorAlertas _revisor;
    private readonly ICurrentUserContext _currentUser;
    private readonly IUnitOfWork _unitOfWork;

    public NotificacionService(
        INotificacionRepository notificacionRepository,
        IRevisorAlertas revisor,
        ICurrentUserContext currentUser,
        IUnitOfWork unitOfWork)
    {
        _notificacionRepository = notificacionRepository;
        _revisor = revisor;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
    }

    public async Task<int> ContarNoLeidasAsync()
    {
        await _revisor.RevisarAsync(_currentUser.RanchoId);
        return await _notificacionRepository.ContarNoLeidasAsync(_currentUser.UsuarioId);
    }

    // De la más reciente a la más antigua.
    public async Task<IReadOnlyList<NotificacionResponse>> ListarAsync()
    {
        var notificaciones = await _notificacionRepository.ListarAsync(_currentUser.UsuarioId, MaximoListado);
        return notificaciones
            .Select(n => new NotificacionResponse(n.Id, n.Tipo, n.Mensaje, n.ReferenciaTipo, n.ReferenciaId, n.Leida, n.Fecha))
            .ToList();
    }

    public async Task MarcarLeidaAsync(Guid id)
    {
        // Una notificación de otro usuario no se encuentra.
        var notificacion = await _notificacionRepository.ObtenerAsync(_currentUser.UsuarioId, id)
            ?? throw new RecursoNoEncontradoException("No se encontró la notificación.");

        if (!notificacion.Leida)
        {
            notificacion.Leida = true;
            await _unitOfWork.GuardarCambiosAsync();
        }
    }

    public async Task MarcarTodasLeidasAsync()
    {
        var noLeidas = await _notificacionRepository.ListarNoLeidasAsync(_currentUser.UsuarioId);
        foreach (var n in noLeidas)
        {
            n.Leida = true;
        }

        if (noLeidas.Count > 0)
        {
            await _unitOfWork.GuardarCambiosAsync();
        }
    }
}
