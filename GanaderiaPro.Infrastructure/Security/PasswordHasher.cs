using GanaderiaPro.Application.Interfaces;
using Microsoft.AspNetCore.Identity;

namespace GanaderiaPro.Infrastructure.Security;

// Envuelve el hasher de contraseñas de ASP.NET Core (PBKDF2) en vez de
// implementar el algoritmo de hashing a mano.
public class PasswordHasher : IPasswordHasher
{
    private readonly Microsoft.AspNetCore.Identity.PasswordHasher<object> _hasher = new();

    public string Hashear(string contrasena) => _hasher.HashPassword(new object(), contrasena);

    public bool Verificar(string contrasenaHasheada, string contrasenaIngresada)
    {
        var resultado = _hasher.VerifyHashedPassword(new object(), contrasenaHasheada, contrasenaIngresada);
        return resultado != PasswordVerificationResult.Failed;
    }
}
