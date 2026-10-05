using GanaderiaPro.Domain.Permisos;

namespace GanaderiaPro.Api.Permisos;

// HU-34: indica a qué módulo pertenece un controlador o una acción. Una
// acción puede indicar otro módulo que el de su controlador.
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class ModuloAttribute : Attribute
{
    public ModuloAttribute(Modulo modulo)
    {
        Modulo = modulo;
    }

    public Modulo Modulo { get; }
}

// Para acciones que puede usar cualquier usuario con sesión, sin importar su
// rol (por ejemplo, cerrar sesión).
[AttributeUsage(AttributeTargets.Method)]
public sealed class SinModuloAttribute : Attribute
{
}
