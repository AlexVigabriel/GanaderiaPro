using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.DTOs;

// HU-41
public record NotificacionResponse(
    Guid Id,
    TipoNotificacion Tipo,
    string Mensaje,
    string ReferenciaTipo,
    Guid ReferenciaId,
    bool Leida,
    DateTime Fecha);
