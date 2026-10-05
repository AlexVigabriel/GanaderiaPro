using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-32: el propietario invita colaboradores con un rol, les cambia el rol y
// les quita o devuelve el acceso.
public class ColaboradorService : IColaboradorService
{
    public static readonly TimeSpan VigenciaInvitacion = TimeSpan.FromDays(7);

    private readonly IUsuarioRepository _usuarioRepository;
    private readonly IInvitacionRepository _invitacionRepository;
    private readonly ICurrentUserContext _currentUser;
    private readonly IUnitOfWork _unitOfWork;

    public ColaboradorService(
        IUsuarioRepository usuarioRepository,
        IInvitacionRepository invitacionRepository,
        ICurrentUserContext currentUser,
        IUnitOfWork unitOfWork)
    {
        _usuarioRepository = usuarioRepository;
        _invitacionRepository = invitacionRepository;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
    }

    public async Task<IReadOnlyList<ColaboradorResponse>> ListarAsync()
    {
        ExigirPropietario();
        var ranchoId = _currentUser.RanchoId;
        var colaboradores = await _usuarioRepository.ListarColaboradoresAsync(ranchoId);
        var vencimientos = await _invitacionRepository.VencimientosPendientesAsync(ranchoId);

        return colaboradores
            .Select(c => ToResponse(c, c.Estado == EstadoUsuario.Pendiente && vencimientos.TryGetValue(c.Id, out var v) ? v : null))
            .ToList();
    }

    public async Task<InvitacionCreadaResponse> InvitarAsync(InvitarColaboradorRequest request)
    {
        ExigirPropietario();

        var nombre = request.Nombre?.Trim() ?? string.Empty;
        if (nombre.Length == 0 || nombre.Length > 150)
        {
            throw new ReglaDeNegocioException("El nombre es obligatorio (hasta 150 caracteres).");
        }

        var email = ReglasCuenta.NormalizarEmail(request.Email);
        if (!EsEmailValido(email))
        {
            throw new ReglaDeNegocioException("Ingresá un correo válido.");
        }

        ValidarRolDeColaborador(request.Rol);

        // RN-02: el correo es único en todo el sistema.
        if (await _usuarioRepository.ExisteEmailAsync(email))
        {
            throw new ReglaDeNegocioException("Ya existe una cuenta registrada con ese correo.");
        }

        var colaborador = new Usuario
        {
            Id = Guid.NewGuid(),
            RanchoId = _currentUser.RanchoId,
            Nombre = nombre,
            Email = email,
            Rol = request.Rol,
            Estado = EstadoUsuario.Pendiente,
            FechaRegistro = DateTime.UtcNow,
        };
        _usuarioRepository.Agregar(colaborador);

        var (codigo, invitacion) = CrearInvitacion(colaborador.Id);
        await _unitOfWork.GuardarCambiosAsync();

        return new InvitacionCreadaResponse(ToResponse(colaborador, invitacion.FechaVencimiento), codigo, invitacion.FechaVencimiento);
    }

    // Un enlace nuevo invalida los anteriores (por ejemplo, si venció o se perdió).
    public async Task<InvitacionCreadaResponse> RegenerarInvitacionAsync(Guid colaboradorId)
    {
        ExigirPropietario();
        var colaborador = await ObtenerColaboradorAsync(colaboradorId);

        if (colaborador.Estado != EstadoUsuario.Pendiente)
        {
            throw new ReglaDeNegocioException("Solo se genera un enlace para colaboradores pendientes.");
        }

        await InvalidarInvitacionesAsync(colaborador.Id);
        var (codigo, invitacion) = CrearInvitacion(colaborador.Id);
        await _unitOfWork.GuardarCambiosAsync();

        return new InvitacionCreadaResponse(ToResponse(colaborador, invitacion.FechaVencimiento), codigo, invitacion.FechaVencimiento);
    }

    public async Task<ColaboradorResponse> CambiarRolAsync(Guid colaboradorId, CambiarRolRequest request)
    {
        ExigirPropietario();
        ValidarRolDeColaborador(request.Rol);
        var colaborador = await ObtenerColaboradorAsync(colaboradorId);

        if (colaborador.Rol != request.Rol)
        {
            colaborador.Rol = request.Rol;
            // Los permisos van en el token: con el rol nuevo tiene que volver a entrar.
            colaborador.VersionSesion++;
            await _unitOfWork.GuardarCambiosAsync();
        }

        return ToResponse(colaborador, null);
    }

    // Desactivar le quita el acceso y cierra sus sesiones. Al reactivarlo
    // vuelve a Activo si ya había entrado, o a Pendiente si nunca aceptó.
    public async Task<ColaboradorResponse> CambiarEstadoAsync(Guid colaboradorId, bool activo)
    {
        ExigirPropietario();
        var colaborador = await ObtenerColaboradorAsync(colaboradorId);

        if (!activo)
        {
            colaborador.Estado = EstadoUsuario.Inactivo;
            colaborador.VersionSesion++;
            await InvalidarInvitacionesAsync(colaborador.Id);
        }
        else if (colaborador.Estado == EstadoUsuario.Inactivo)
        {
            colaborador.Estado = string.IsNullOrEmpty(colaborador.PasswordHash) ? EstadoUsuario.Pendiente : EstadoUsuario.Activo;
        }

        await _unitOfWork.GuardarCambiosAsync();
        return ToResponse(colaborador, null);
    }

    // Solo el propietario gestiona colaboradores.
    private void ExigirPropietario()
    {
        if (_currentUser.Rol != RolUsuario.Propietario)
        {
            throw new AccesoDenegadoException("Solo el propietario puede gestionar colaboradores.");
        }
    }

    private static void ValidarRolDeColaborador(RolUsuario rol)
    {
        if (!Usuario.RolesDeColaborador.Contains(rol))
        {
            throw new ReglaDeNegocioException("Elegí un rol de colaborador: Veterinario, Encargado de corrales o Encargado de ingreso.");
        }
    }

    // RN-16: solo colaboradores del rancho actual (nunca el propietario).
    private async Task<Usuario> ObtenerColaboradorAsync(Guid id)
    {
        var usuario = await _usuarioRepository.ObtenerDelRanchoAsync(_currentUser.RanchoId, id);
        if (usuario is null || !usuario.EsColaborador)
        {
            throw new RecursoNoEncontradoException("No se encontró el colaborador.");
        }

        return usuario;
    }

    private (string Codigo, Invitacion Invitacion) CrearInvitacion(Guid usuarioId)
    {
        var ahora = DateTime.UtcNow;
        var codigo = CodigoInvitacion.Generar();
        var invitacion = new Invitacion
        {
            Id = Guid.NewGuid(),
            UsuarioId = usuarioId,
            CodigoHash = CodigoInvitacion.Hash(codigo),
            FechaCreacion = ahora,
            FechaVencimiento = ahora.Add(VigenciaInvitacion),
        };
        _invitacionRepository.Agregar(invitacion);
        return (codigo, invitacion);
    }

    private async Task InvalidarInvitacionesAsync(Guid usuarioId)
    {
        var ahora = DateTime.UtcNow;
        foreach (var invitacion in await _invitacionRepository.ListarSinUsarAsync(usuarioId))
        {
            invitacion.FechaVencimiento = ahora;
        }
    }

    private static bool EsEmailValido(string email)
    {
        var arroba = email.IndexOf('@');
        return email.Length <= 200 && arroba > 0 && email.LastIndexOf('@') == arroba &&
               email.IndexOf('.', arroba) > arroba + 1 && !email.EndsWith('.') && !email.Contains(' ');
    }

    private static ColaboradorResponse ToResponse(Usuario u, DateTime? invitacionVence) =>
        new(u.Id, u.Nombre, u.Email, u.Rol, u.Estado, u.UltimoAcceso, invitacionVence);
}
