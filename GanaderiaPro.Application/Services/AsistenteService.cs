using System.Globalization;
using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Eventos;
using GanaderiaPro.Domain.Permisos;

namespace GanaderiaPro.Application.Services;

// HU-36.1 y HU-38: asistente de consultas con un catálogo de preguntas
// predefinidas (sin IA: eso es HU-36.3, Release 2). Responde con los mismos
// datos y cálculos que los módulos, así el valor coincide exactamente. Si la
// pregunta se reconoce pero el dato no está registrado, dice quién debe
// cargarlo (RN-12) y le avisa con una notificación.
public class AsistenteService : IAsistenteService
{
    public const string MensajeSinDatos = "No encontramos información actualizada sobre este dato.";

    // Catálogo de consultas soportadas (va también en el manual de usuario).
    public static readonly IReadOnlyList<string> Ejemplos =
    [
        "¿Cuántos animales hay?",
        "¿Cuántas hembras hay en el corral Norte?",
        "¿Cuántos machos de raza Nelore hay?",
        "¿Cuántos animales se vendieron?",
        "¿Cuántos animales fallecieron?",
        "¿Cuál es el peso promedio?",
        "¿Cuánto pesa el AR-002?",
        "¿En qué corral está el AR-002?",
        "¿Cuándo se vacunó el AR-002?",
        "¿Cuántas vacunaciones pendientes hay?",
        "¿Cuántas están próximas a parir?",
        "¿Cuántos corrales hay?",
    ];

    private static readonly CultureInfo Cultura = CultureInfo.InvariantCulture;
    private static readonly string[] PalabrasHembra = ["hembra", "hembras", "vaca", "vacas", "vaquillona", "vaquillonas", "ternera", "terneras"];
    private static readonly string[] PalabrasMacho = ["macho", "machos", "toro", "toros", "novillo", "novillos", "torito", "toritos", "ternero", "terneros"];

    private readonly IAnimalRepository _animalRepository;
    private readonly ICorralRepository _corralRepository;
    private readonly IVacunacionRepository _vacunacionRepository;
    private readonly IPrenezRepository _prenezRepository;
    private readonly IUsuarioRepository _usuarioRepository;
    private readonly IPublicadorEventos _publicador;
    private readonly ICurrentUserContext _currentUser;

    public AsistenteService(
        IAnimalRepository animalRepository,
        ICorralRepository corralRepository,
        IVacunacionRepository vacunacionRepository,
        IPrenezRepository prenezRepository,
        IUsuarioRepository usuarioRepository,
        IPublicadorEventos publicador,
        ICurrentUserContext currentUser)
    {
        _animalRepository = animalRepository;
        _corralRepository = corralRepository;
        _vacunacionRepository = vacunacionRepository;
        _prenezRepository = prenezRepository;
        _usuarioRepository = usuarioRepository;
        _publicador = publicador;
        _currentUser = currentUser;
    }

    public async Task<RespuestaAsistenteResponse> ConsultarAsync(string? texto)
    {
        var pregunta = new PreguntaAsistente(texto);
        if (pregunta.Texto.Length == 0)
        {
            return NoReconocida();
        }

        var ranchoId = _currentUser.RanchoId;

        // El orden importa: «¿Cuánto pesa…?» también empieza con «cuant».
        if (pregunta.Contiene("peso", "pesa"))
        {
            if (!PuedeVer(Modulo.Pesaje, out var denegada)) return denegada;
            var activos = await ActivosAsync();
            var (animal, arete) = BuscarAnimal(pregunta, activos);
            if (arete is not null) return AreteNoEncontrado(arete);
            return animal is not null ? await PesoDeAnimalAsync(animal) : await PesoPromedioAsync(pregunta, activos);
        }

        if (pregunta.Contiene("vacun"))
        {
            if (!PuedeVer(Modulo.Sanidad, out var denegada)) return denegada;
            var (animal, arete) = BuscarAnimal(pregunta, await ActivosAsync());
            if (arete is not null) return AreteNoEncontrado(arete);
            if (animal is not null)
            {
                return await UltimaVacunacionAsync(animal);
            }

            var vacunaciones = await _vacunacionRepository.ListarDeActivosAsync(ranchoId);
            if (pregunta.Contiene("pendiente"))
            {
                // RN-09: mismo cálculo que el módulo Sanidad (HU-27).
                var pendientes = PendientesSanidad.Calcular(vacunaciones).Count;
                return Respuesta(pendientes == 1 ? "Hay 1 vacunación pendiente." : $"Hay {pendientes} vacunaciones pendientes.");
            }

            var vacunados = vacunaciones.Select(v => v.AnimalId).Distinct().Count();
            return Respuesta(vacunados == 1 ? "Hay 1 animal vacunado." : $"Hay {vacunados} animales vacunados.");
        }

        if (pregunta.Contiene("parir", "parto", "prenad"))
        {
            if (!PuedeVer(Modulo.Reproduccion, out var denegada)) return denegada;
            // RN-10: mismo cálculo que el tablero (HU-12).
            var cantidad = (await _prenezRepository.ListarAbiertasConPartoHastaAsync(ranchoId, FechaRancho.Hoy().AddDays(30))).Count;
            return Respuesta(cantidad == 1
                ? "Hay 1 hembra próxima a parir en los próximos 30 días."
                : $"Hay {cantidad} hembras próximas a parir en los próximos 30 días.");
        }

        if (pregunta.Contiene("corral") && (pregunta.Contiene("donde", "que corral", "en que", "cual corral")))
        {
            var (animal, arete) = BuscarAnimal(pregunta, await ActivosAsync());
            if (arete is not null) return AreteNoEncontrado(arete);
            if (animal is not null)
            {
                if (!PuedeVer(Modulo.Corrales, out var denegada)) return denegada;
                return await CorralDeAnimalAsync(animal);
            }
        }

        if (pregunta.Contiene("cuant") && pregunta.ContienePalabras("corrales"))
        {
            if (!PuedeVer(Modulo.Corrales, out var denegada)) return denegada;
            var corrales = (await _corralRepository.ListarAsync(ranchoId, incluirInactivos: false)).Count;
            return Respuesta(corrales == 1 ? "Hay 1 corral activo." : $"Hay {corrales} corrales activos.");
        }

        if (pregunta.Contiene("cuant"))
        {
            if (!PuedeVer(Modulo.Ganado, out var denegada)) return denegada;
            return await ConteoAsync(pregunta);
        }

        return NoReconocida();
    }

    // ---- Cantidades (animales por corral, sexo, raza o estado)

    private async Task<RespuestaAsistenteResponse> ConteoAsync(PreguntaAsistente pregunta)
    {
        var estado = pregunta.Contiene("vend") ? EstadoAnimal.Vendido
            : pregunta.Contiene("fallec", "muert", "murieron") ? EstadoAnimal.Fallecido
            : EstadoAnimal.Activo;
        SexoAnimal? sexo = PalabrasHembra.Any(pregunta.ContienePalabras) ? SexoAnimal.Hembra
            : PalabrasMacho.Any(pregunta.ContienePalabras) ? SexoAnimal.Macho
            : null;

        var animales = await _animalRepository.BuscarAsync(_currentUser.RanchoId, null, estado, sexo, null);

        var corral = await BuscarCorralAsync(pregunta);
        if (corral.NoEncontrado is { } nombre)
        {
            return Respuesta($"No encontré el corral «{nombre}». Revisá el nombre en el módulo Corrales.");
        }

        if (corral.Corral is { } c)
        {
            animales = animales.Where(a => a.CorralId == c.Id).ToList();
        }

        var raza = animales.Select(a => a.Raza)
            .Concat((await ActivosAsync()).Select(a => a.Raza))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Where(r => !string.IsNullOrWhiteSpace(r) && pregunta.ContienePalabras(r))
            .OrderByDescending(r => r.Length)
            .FirstOrDefault();
        if (raza is not null)
        {
            animales = animales.Where(a => string.Equals(a.Raza, raza, StringComparison.OrdinalIgnoreCase)).ToList();
        }

        var cantidad = animales.Count;
        var sustantivo = (sexo, cantidad == 1) switch
        {
            (SexoAnimal.Hembra, true) => "hembra",
            (SexoAnimal.Hembra, false) => "hembras",
            (SexoAnimal.Macho, true) => "macho",
            (SexoAnimal.Macho, false) => "machos",
            (_, true) => "animal",
            _ => "animales",
        };
        var femenino = sexo == SexoAnimal.Hembra;
        var adjetivo = estado switch
        {
            EstadoAnimal.Vendido => femenino ? "vendida" : "vendido",
            EstadoAnimal.Fallecido => femenino ? "fallecida" : "fallecido",
            _ => femenino ? "activa" : "activo",
        };
        if (cantidad != 1)
        {
            adjetivo += "s";
        }

        var detalle = (raza is null ? string.Empty : $" de raza {raza}") +
                      (corral.Corral is null ? string.Empty : $" en el corral «{corral.Corral.Nombre}»");
        return Respuesta($"Hay {cantidad} {sustantivo} {adjetivo}{detalle}.");
    }

    private async Task<(Corral? Corral, string? NoEncontrado)> BuscarCorralAsync(PreguntaAsistente pregunta)
    {
        var palabras = pregunta.Palabras;
        var indice = palabras.ToList().IndexOf("corral");
        if (indice < 0)
        {
            return (null, null);
        }

        var corrales = await _corralRepository.ListarAsync(_currentUser.RanchoId, incluirInactivos: false);
        // Acepta «corral Norte» y también «Corral 3» escrito como «corral 3».
        var encontrado = corrales
            .Where(c => pregunta.ContienePalabras(c.Nombre) || pregunta.ContienePalabras($"corral {c.Nombre}"))
            .OrderByDescending(c => c.Nombre.Length)
            .FirstOrDefault();
        if (encontrado is not null)
        {
            return (encontrado, null);
        }

        var siguiente = indice + 1 < palabras.Count ? palabras[indice + 1] : null;
        return siguiente is null || siguiente is "hay" or "tiene" or "tienen" ? (null, null) : (null, siguiente);
    }

    // ---- Datos de un animal (pueden faltar: HU-38)

    private async Task<RespuestaAsistenteResponse> PesoDeAnimalAsync(Animal animal)
    {
        if (animal.Peso is not { } peso)
        {
            return await SinDatosAsync($"el peso del animal {animal.Arete}", RolUsuario.EncargadoCorrales, $"peso:{animal.Id}");
        }

        return Respuesta($"El animal {animal.Arete} pesa {peso.ToString("0.##", Cultura)} kg.");
    }

    private async Task<RespuestaAsistenteResponse> PesoPromedioAsync(PreguntaAsistente pregunta, IReadOnlyList<Animal> activos)
    {
        var corral = await BuscarCorralAsync(pregunta);
        if (corral.NoEncontrado is { } nombre)
        {
            return Respuesta($"No encontré el corral «{nombre}». Revisá el nombre en el módulo Corrales.");
        }

        var animales = corral.Corral is { } c ? activos.Where(a => a.CorralId == c.Id) : activos;
        var pesos = animales.Where(a => a.Peso is not null).Select(a => a.Peso!.Value).ToList();
        var donde = corral.Corral is null ? string.Empty : $" del corral «{corral.Corral.Nombre}»";
        if (pesos.Count == 0)
        {
            return await SinDatosAsync($"el peso de los animales{donde}", RolUsuario.EncargadoCorrales,
                $"peso-promedio:{corral.Corral?.Id.ToString() ?? "rancho"}");
        }

        var promedio = Math.Round(pesos.Average(), 1);
        var cuantos = pesos.Count == 1 ? "1 animal" : $"{pesos.Count} animales";
        return Respuesta($"El peso promedio{donde} es {promedio.ToString("0.#", Cultura)} kg ({cuantos} con peso registrado).");
    }

    private async Task<RespuestaAsistenteResponse> CorralDeAnimalAsync(Animal animal)
    {
        if (animal.CorralId is null)
        {
            return await SinDatosAsync($"el corral del animal {animal.Arete}", RolUsuario.EncargadoCorrales, $"corral:{animal.Id}");
        }

        return Respuesta($"El animal {animal.Arete} está en el corral «{animal.Corral?.Nombre}».");
    }

    private async Task<RespuestaAsistenteResponse> UltimaVacunacionAsync(Animal animal)
    {
        var ultima = (await _vacunacionRepository.ListarPorAnimalAsync(animal.Id))
            .OrderByDescending(v => v.FechaAplicacion)
            .FirstOrDefault();
        if (ultima is null)
        {
            return await SinDatosAsync($"vacunaciones del animal {animal.Arete}", RolUsuario.Veterinario, $"vacuna:{animal.Id}");
        }

        return Respuesta(
            $"La última vacunación del animal {animal.Arete} fue {ultima.Vacuna?.Nombre ?? "una vacuna"} el {ultima.FechaAplicacion:dd/MM/yyyy}.");
    }

    // HU-38: dice quién debe registrar el dato (RN-12) y le avisa.
    private async Task<RespuestaAsistenteResponse> SinDatosAsync(string dato, RolUsuario rolResponsable, string clave)
    {
        var usuarios = await _usuarioRepository.ListarActivosAsync(_currentUser.RanchoId);
        // RN-12: si no hay ningún colaborador con ese rol, el responsable es el propietario.
        var responsable = usuarios.FirstOrDefault(u => u.Rol == rolResponsable)
            ?? usuarios.FirstOrDefault(u => u.Rol == RolUsuario.Propietario);
        var nombre = responsable is null ? "el propietario" : $"{responsable.Nombre} ({NombreDeRol(responsable.Rol)})";

        await _publicador.PublicarAsync(new DatoFaltante(_currentUser.RanchoId, dato, rolResponsable, clave));

        return new RespuestaAsistenteResponse(
            $"{MensajeSinDatos} Responsable de registrarlo: {nombre}. Ya le avisamos.",
            Reconocida: true,
            SinDatos: true,
            Responsable: responsable?.Nombre,
            Ejemplos: []);
    }

    // ---- Apoyo

    private IReadOnlyList<Animal>? _activos;

    private async Task<IReadOnlyList<Animal>> ActivosAsync() =>
        _activos ??= await _animalRepository.BuscarAsync(_currentUser.RanchoId, null, EstadoAnimal.Activo, null, null);

    // Devuelve el animal del arete mencionado, o el arete si no hay ningún
    // animal activo con él. Sin arete en la pregunta, ambos quedan en null.
    private static (Animal? Animal, string? AreteNoEncontrado) BuscarAnimal(PreguntaAsistente pregunta, IReadOnlyList<Animal> activos)
    {
        string? primero = null;
        foreach (var posible in pregunta.PosiblesAretes())
        {
            primero ??= posible;
            var animal = activos.FirstOrDefault(a => string.Equals(a.Arete, posible, StringComparison.OrdinalIgnoreCase));
            if (animal is not null)
            {
                return (animal, null);
            }
        }

        return (null, primero);
    }

    private static RespuestaAsistenteResponse AreteNoEncontrado(string arete) =>
        Respuesta($"No encontré un animal activo con el arete {arete}.");

    // HU-36.1: cada rol solo recibe información de los módulos que puede ver.
    private bool PuedeVer(Modulo modulo, out RespuestaAsistenteResponse denegada)
    {
        denegada = Respuesta("Tu rol no tiene acceso a esa información.");
        return MatrizPermisos.Permite(_currentUser.Rol, modulo, NivelAcceso.Lectura);
    }

    private static string NombreDeRol(RolUsuario rol) => rol switch
    {
        RolUsuario.EncargadoCorrales => "Encargado de corrales",
        RolUsuario.EncargadoIngreso => "Encargado de ingreso",
        _ => rol.ToString(),
    };

    private static RespuestaAsistenteResponse Respuesta(string texto) =>
        new(texto, Reconocida: true, SinDatos: false, Responsable: null, Ejemplos: []);

    // No inventa datos: devuelve ejemplos de preguntas soportadas.
    private static RespuestaAsistenteResponse NoReconocida() =>
        new("No entendí la pregunta. Probá con alguna de estas:", Reconocida: false, SinDatos: false, Responsable: null, Ejemplos: Ejemplos);
}
