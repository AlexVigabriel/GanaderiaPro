namespace GanaderiaPro.Application.Interfaces;

public interface IPasswordHasher
{
    string Hashear(string contrasena);
    bool Verificar(string contrasenaHasheada, string contrasenaIngresada);
}
