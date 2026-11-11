using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Common;

// HU-29 y HU-32: reglas comunes para dar de alta a alguien por invitación
// (socios y colaboradores). Viven en un solo lugar para no repetirlas (DRY).
public static class AltaInvitado
{
    public static readonly TimeSpan VigenciaInvitacion = TimeSpan.FromDays(7);

    public static string ValidarNombre(string? nombre)
    {
        var limpio = nombre?.Trim() ?? string.Empty;
        if (limpio.Length == 0 || limpio.Length > 150)
        {
            throw new ReglaDeNegocioException("El nombre es obligatorio (hasta 150 caracteres).");
        }

        return limpio;
    }

    public static string ValidarEmail(string? email)
    {
        var normalizado = ReglasCuenta.NormalizarEmail(email);
        if (!EsEmailValido(normalizado))
        {
            throw new ReglaDeNegocioException("Ingresá un correo válido.");
        }

        return normalizado;
    }

    // El código va una sola vez en la respuesta; en la base queda solo su hash.
    public static (string Codigo, Invitacion Invitacion) CrearInvitacion(IInvitacionRepository repositorio, Guid usuarioId)
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
        repositorio.Agregar(invitacion);
        return (codigo, invitacion);
    }

    public static async Task InvalidarInvitacionesAsync(IInvitacionRepository repositorio, Guid usuarioId)
    {
        var ahora = DateTime.UtcNow;
        foreach (var invitacion in await repositorio.ListarSinUsarAsync(usuarioId))
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
}
