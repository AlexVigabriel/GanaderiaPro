using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.DTOs;

public record InvitarColaboradorRequest(string Nombre, string Email, RolUsuario Rol);

public record CambiarRolRequest(RolUsuario Rol);

public record ColaboradorResponse(
    Guid Id,
    string Nombre,
    string Email,
    RolUsuario Rol,
    EstadoUsuario Estado,
    DateTime? UltimoAcceso,
    DateTime? InvitacionVence);

// El código va solo en esta respuesta: no se puede volver a leer después.
public record InvitacionCreadaResponse(ColaboradorResponse Colaborador, string Codigo, DateTime Vence);

// Lo que ve el colaborador al abrir el enlace.
public record InvitacionResponse(string Rancho, string Nombre, string Email, RolUsuario Rol, DateTime Vence);

public record AceptarInvitacionRequest(string Contrasena, string ConfirmarContrasena);
