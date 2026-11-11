using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Planes;

namespace GanaderiaPro.Application.Services;

// HU-29 y HU-30: el propietario invita socios (solo lectura, sección 5) y ve
// su listado con estado y último acceso. Editar o quitar socios es HU-31
// (Release 2).
public class SocioService : ISocioService
{
    private readonly IUsuarioRepository _usuarioRepository;
    private readonly IInvitacionRepository _invitacionRepository;
    private readonly ICurrentUserContext _currentUser;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IControlLimitesPlan _limitesPlan;

    public SocioService(
        IUsuarioRepository usuarioRepository,
        IInvitacionRepository invitacionRepository,
        ICurrentUserContext currentUser,
        IUnitOfWork unitOfWork,
        IControlLimitesPlan limitesPlan)
    {
        _usuarioRepository = usuarioRepository;
        _invitacionRepository = invitacionRepository;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
        _limitesPlan = limitesPlan;
    }

    public async Task<IReadOnlyList<ColaboradorResponse>> ListarAsync()
    {
        ExigirPropietario();
        var ranchoId = _currentUser.RanchoId;
        var socios = await _usuarioRepository.ListarSociosAsync(ranchoId);
        var vencimientos = await _invitacionRepository.VencimientosPendientesAsync(ranchoId);

        return socios
            .Select(s => ToResponse(s, s.Estado == EstadoUsuario.Pendiente && vencimientos.TryGetValue(s.Id, out var v) ? v : null))
            .ToList();
    }

    public async Task<InvitacionCreadaResponse> InvitarAsync(InvitarSocioRequest request)
    {
        ExigirPropietario();

        var nombre = AltaInvitado.ValidarNombre(request.Nombre);
        var email = AltaInvitado.ValidarEmail(request.Email);

        // RN-02: el correo es único en todo el sistema.
        if (await _usuarioRepository.ExisteEmailAsync(email))
        {
            throw new ReglaDeNegocioException("Ya existe una cuenta registrada con ese correo.");
        }

        // RN-11: límite de socios del plan (Pendientes y Activos).
        await _limitesPlan.VerificarAsync(RecursoPlan.Socios);

        var socio = new Usuario
        {
            Id = Guid.NewGuid(),
            RanchoId = _currentUser.RanchoId,
            Nombre = nombre,
            Email = email,
            Rol = RolUsuario.Socio,
            Estado = EstadoUsuario.Pendiente,
            FechaRegistro = DateTime.UtcNow,
        };
        _usuarioRepository.Agregar(socio);

        var (codigo, invitacion) = AltaInvitado.CrearInvitacion(_invitacionRepository, socio.Id);
        await _unitOfWork.GuardarCambiosAsync();

        return new InvitacionCreadaResponse(ToResponse(socio, invitacion.FechaVencimiento), codigo, invitacion.FechaVencimiento);
    }

    public async Task<InvitacionCreadaResponse> RegenerarInvitacionAsync(Guid socioId)
    {
        ExigirPropietario();
        var socio = await _usuarioRepository.ObtenerDelRanchoAsync(_currentUser.RanchoId, socioId);
        if (socio is null || socio.Rol != RolUsuario.Socio)
        {
            throw new RecursoNoEncontradoException("No se encontró el socio.");
        }

        if (socio.Estado != EstadoUsuario.Pendiente)
        {
            throw new ReglaDeNegocioException("Solo se genera un enlace para socios pendientes.");
        }

        await AltaInvitado.InvalidarInvitacionesAsync(_invitacionRepository, socio.Id);
        var (codigo, invitacion) = AltaInvitado.CrearInvitacion(_invitacionRepository, socio.Id);
        await _unitOfWork.GuardarCambiosAsync();

        return new InvitacionCreadaResponse(ToResponse(socio, invitacion.FechaVencimiento), codigo, invitacion.FechaVencimiento);
    }

    private void ExigirPropietario()
    {
        if (_currentUser.Rol != RolUsuario.Propietario)
        {
            throw new AccesoDenegadoException("Solo el propietario puede gestionar socios.");
        }
    }

    private static ColaboradorResponse ToResponse(Usuario u, DateTime? invitacionVence) =>
        new(u.Id, u.Nombre, u.Email, u.Rol, u.Estado, u.UltimoAcceso, invitacionVence);
}
