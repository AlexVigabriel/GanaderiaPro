using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Permisos;

namespace GanaderiaPro.Application.DTOs;

public record RegistrarCuentaRequest(
    string Nombre,
    string Email,
    string Contrasena,
    string ConfirmarContrasena,
    string NombreRancho,
    PlanSuscripcion Plan);

public record RegistrarCuentaResponse(Guid RanchoId, Guid UsuarioId, string Mensaje);

public record IniciarSesionRequest(string Email, string Contrasena);

// HU-34: los permisos del rol van con la sesión para que la app arme el
// menú y oculte los botones que el usuario no puede usar.
public record IniciarSesionResponse(
    string Token,
    string NombreRancho,
    string NombreUsuario,
    RolUsuario Rol,
    IReadOnlyDictionary<Modulo, NivelAcceso> Permisos);
