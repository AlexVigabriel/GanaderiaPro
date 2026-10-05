using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-32: el colaborador abre el enlace y define su contraseña. Sigue
// Pendiente hasta su primer inicio de sesión.
public class InvitacionService : IInvitacionService
{
    private const string MensajeEnlaceInvalido =
        "El enlace no es válido o ya venció. Pedile al propietario del rancho uno nuevo.";

    private readonly IInvitacionRepository _invitacionRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IUnitOfWork _unitOfWork;

    public InvitacionService(IInvitacionRepository invitacionRepository, IPasswordHasher passwordHasher, IUnitOfWork unitOfWork)
    {
        _invitacionRepository = invitacionRepository;
        _passwordHasher = passwordHasher;
        _unitOfWork = unitOfWork;
    }

    public async Task<InvitacionResponse> ObtenerAsync(string codigo)
    {
        var invitacion = await ObtenerVigenteAsync(codigo);
        var u = invitacion.Usuario!;
        return new InvitacionResponse(u.Rancho?.Nombre ?? string.Empty, u.Nombre, u.Email, u.Rol, invitacion.FechaVencimiento);
    }

    public async Task AceptarAsync(string codigo, AceptarInvitacionRequest request)
    {
        var invitacion = await ObtenerVigenteAsync(codigo);

        if (request.Contrasena != request.ConfirmarContrasena)
        {
            throw new ReglaDeNegocioException("Las contraseñas no coinciden.");
        }

        if (!ReglasCuenta.EsContrasenaValida(request.Contrasena))
        {
            throw new ReglaDeNegocioException(ReglasCuenta.MensajeContrasena);
        }

        // El enlace sirve una sola vez.
        invitacion.FechaUso = DateTime.UtcNow;
        invitacion.Usuario!.PasswordHash = _passwordHasher.Hashear(request.Contrasena);
        await _unitOfWork.GuardarCambiosAsync();
    }

    // Mismo mensaje si el código no existe, venció, ya se usó o el
    // colaborador fue desactivado: no se revela cuál de los casos es.
    private async Task<Invitacion> ObtenerVigenteAsync(string codigo)
    {
        var invitacion = await _invitacionRepository.ObtenerPorHashAsync(CodigoInvitacion.Hash(codigo));
        if (invitacion is null || !invitacion.EstaVigente(DateTime.UtcNow) || invitacion.Usuario?.Estado != EstadoUsuario.Pendiente)
        {
            throw new ReglaDeNegocioException(MensajeEnlaceInvalido);
        }

        return invitacion;
    }
}
