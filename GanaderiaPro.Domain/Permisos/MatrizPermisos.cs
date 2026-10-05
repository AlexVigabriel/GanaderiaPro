using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Domain.Permisos;

// HU-34: módulos del sistema sobre los que se dan permisos.
public enum Modulo
{
    Ganado,
    Pesaje,
    Corrales,
    Sanidad,
    Colaboradores,
    Tablero,
    // HU-58: plan del rancho y su uso. Solo el propietario.
    Configuracion
}

// Ninguno: no entra. Lectura: solo consulta. Escritura: consulta y modifica.
public enum NivelAcceso
{
    Ninguno,
    Lectura,
    Escritura
}

// HU-34: matriz de permisos del backlog (sección 5). Es el único lugar donde
// se define qué puede hacer cada rol: la usan el servidor para permitir o
// rechazar cada pedido y la app para mostrar u ocultar menús y botones.
// Los módulos que todavía no existen (Reproducción, Importar/Exportar Excel,
// Configuración) se suman acá cuando se implementen.
public static class MatrizPermisos
{
    private const NivelAcceso E = NivelAcceso.Escritura;
    private const NivelAcceso L = NivelAcceso.Lectura;
    private const NivelAcceso N = NivelAcceso.Ninguno;

    private static readonly IReadOnlyDictionary<RolUsuario, IReadOnlyDictionary<Modulo, NivelAcceso>> Matriz =
        new Dictionary<RolUsuario, IReadOnlyDictionary<Modulo, NivelAcceso>>
        {
            [RolUsuario.Propietario] = Fila(ganado: E, pesaje: E, corrales: E, sanidad: E, colaboradores: E),
            [RolUsuario.Socio] = Fila(ganado: L, pesaje: L, corrales: L, sanidad: L, colaboradores: N),
            [RolUsuario.Veterinario] = Fila(ganado: L, pesaje: E, corrales: L, sanidad: E, colaboradores: N),
            [RolUsuario.EncargadoCorrales] = Fila(ganado: L, pesaje: E, corrales: E, sanidad: L, colaboradores: N),
            [RolUsuario.EncargadoIngreso] = Fila(ganado: E, pesaje: E, corrales: L, sanidad: L, colaboradores: N),
        };

    // El tablero es de solo lectura para todos los roles.
    private static IReadOnlyDictionary<Modulo, NivelAcceso> Fila(
        NivelAcceso ganado, NivelAcceso pesaje, NivelAcceso corrales, NivelAcceso sanidad, NivelAcceso colaboradores) =>
        new Dictionary<Modulo, NivelAcceso>
        {
            [Modulo.Ganado] = ganado,
            [Modulo.Pesaje] = pesaje,
            [Modulo.Corrales] = corrales,
            [Modulo.Sanidad] = sanidad,
            [Modulo.Colaboradores] = colaboradores,
            [Modulo.Tablero] = L,
            [Modulo.Configuracion] = colaboradores,
        };

    public static NivelAcceso Acceso(RolUsuario rol, Modulo modulo) =>
        Matriz.TryGetValue(rol, out var fila) && fila.TryGetValue(modulo, out var nivel) ? nivel : N;

    public static bool Permite(RolUsuario rol, Modulo modulo, NivelAcceso requerido) => Acceso(rol, modulo) >= requerido;

    public static IReadOnlyDictionary<Modulo, NivelAcceso> PermisosDe(RolUsuario rol) =>
        Enum.GetValues<Modulo>().ToDictionary(m => m, m => Acceso(rol, m));
}
