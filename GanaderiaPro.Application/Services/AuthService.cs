using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

public class AuthService : IAuthService
{
    private const string MensajeCredencialesInvalidas = "Correo o contraseña incorrectos.";

    private readonly IUsuarioRepository _usuarioRepository;
    private readonly IRanchoRepository _ranchoRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ITokenGenerator _tokenGenerator;
    private readonly IUnitOfWork _unitOfWork;

    public AuthService(
        IUsuarioRepository usuarioRepository,
        IRanchoRepository ranchoRepository,
        IPasswordHasher passwordHasher,
        ITokenGenerator tokenGenerator,
        IUnitOfWork unitOfWork)
    {
        _usuarioRepository = usuarioRepository;
        _ranchoRepository = ranchoRepository;
        _passwordHasher = passwordHasher;
        _tokenGenerator = tokenGenerator;
        _unitOfWork = unitOfWork;
    }

    public async Task<RegistrarCuentaResponse> RegistrarAsync(RegistrarCuentaRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Nombre) ||
            string.IsNullOrWhiteSpace(request.Email) ||
            string.IsNullOrWhiteSpace(request.NombreRancho))
        {
            throw new ReglaDeNegocioException("Nombre, correo y nombre del rancho son obligatorios.");
        }

        // HU-08: la contraseña y su confirmación deben coincidir.
        if (request.Contrasena != request.ConfirmarContrasena)
        {
            throw new ReglaDeNegocioException("Las contraseñas no coinciden.");
        }

        // RN-03: mínimo 8 caracteres, con al menos una letra y un número.
        if (!EsContrasenaValida(request.Contrasena))
        {
            throw new ReglaDeNegocioException(
                "La contraseña debe tener al menos 8 caracteres, con al menos una letra y un número.");
        }

        // RN-02: el correo es único en todo el sistema.
        if (await _usuarioRepository.ExisteEmailAsync(request.Email))
        {
            throw new ReglaDeNegocioException("Ya existe una cuenta registrada con ese correo.");
        }

        var ahora = DateTime.UtcNow;

        var rancho = new Rancho
        {
            Id = Guid.NewGuid(),
            Nombre = request.NombreRancho,
            Plan = request.Plan,
            FechaRegistro = ahora,
            // RN-15: la prueba gratuita dura 10 días desde el registro.
            FechaFinPruebaGratuita = ahora.AddDays(10),
        };

        var usuario = new Usuario
        {
            Id = Guid.NewGuid(),
            RanchoId = rancho.Id,
            Nombre = request.Nombre,
            Email = request.Email,
            PasswordHash = _passwordHasher.Hashear(request.Contrasena),
            Rol = RolUsuario.Propietario,
            FechaRegistro = ahora,
            Activo = true,
        };

        _ranchoRepository.Agregar(rancho);
        _usuarioRepository.Agregar(usuario);
        await _unitOfWork.GuardarCambiosAsync();

        return new RegistrarCuentaResponse(rancho.Id, usuario.Id, "Comienza tu prueba gratuita de 10 días");
    }

    public async Task<IniciarSesionResponse> IniciarSesionAsync(IniciarSesionRequest request)
    {
        var usuario = await _usuarioRepository.ObtenerPorEmailAsync(request.Email);

        // HU-09: el mensaje de error es el mismo tanto si el correo no existe
        // como si la contraseña es incorrecta — no se revela cuál de los dos falló.
        if (usuario is null || !_passwordHasher.Verificar(usuario.PasswordHash, request.Contrasena))
        {
            throw new ReglaDeNegocioException(MensajeCredencialesInvalidas);
        }

        var token = _tokenGenerator.GenerarToken(usuario);

        return new IniciarSesionResponse(token, usuario.Rancho?.Nombre ?? string.Empty, usuario.Nombre);
    }

    // HU-52: invalida en el servidor todos los tokens emitidos hasta ahora
    // para este usuario (en este y en cualquier otro dispositivo).
    public async Task CerrarSesionAsync(Guid usuarioId)
    {
        var usuario = await _usuarioRepository.ObtenerPorIdAsync(usuarioId);
        if (usuario is null)
        {
            return;
        }

        usuario.VersionSesion++;
        await _unitOfWork.GuardarCambiosAsync();
    }

    // Un token sirve solo si su versión de sesión es la actual y el usuario
    // sigue activo. Se revisa en cada pedido autenticado.
    public async Task<bool> SesionVigenteAsync(Guid usuarioId, int versionDelToken)
    {
        var usuario = await _usuarioRepository.ObtenerPorIdAsync(usuarioId);
        return usuario is { Activo: true } && usuario.VersionSesion == versionDelToken;
    }

    private static bool EsContrasenaValida(string contrasena) =>
        contrasena.Length >= 8 && contrasena.Any(char.IsLetter) && contrasena.Any(char.IsDigit);
}
