namespace GanaderiaPro.Application.Exceptions;

// El usuario no tiene permiso para esa acción: la API responde 403.
public class AccesoDenegadoException : Exception
{
    public AccesoDenegadoException(string message) : base(message)
    {
    }
}
