using System.Security.Cryptography;
using System.Text;

namespace GanaderiaPro.Application.Common;

// HU-32: código aleatorio del enlace de invitación y su hash (SHA-256).
public static class CodigoInvitacion
{
    public static string Generar() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    public static string Hash(string codigo) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(codigo ?? string.Empty)));
}
