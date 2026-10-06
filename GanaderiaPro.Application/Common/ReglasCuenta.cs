namespace GanaderiaPro.Application.Common;

// Reglas de las cuentas que se usan al registrarse (HU-07) y al aceptar una
// invitación (HU-32): en un solo lugar (DRY).
public static class ReglasCuenta
{
    public const string MensajeContrasena =
        "La contraseña debe tener al menos 8 caracteres, con al menos una letra y un número.";

    // RN-02: "Ana@correo.com" y "ana@correo.com" son el mismo correo.
    public static string NormalizarEmail(string? email) => (email ?? string.Empty).Trim().ToLowerInvariant();

    // RN-03: mínimo 8 caracteres, con al menos una letra y un número.
    public static bool EsContrasenaValida(string? contrasena) =>
        contrasena is not null && contrasena.Length >= 8 && contrasena.Any(char.IsLetter) && contrasena.Any(char.IsDigit);
}
