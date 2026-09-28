using GanaderiaPro.Domain.Entities;

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

public record IniciarSesionResponse(string Token, string NombreRancho, string NombreUsuario);
