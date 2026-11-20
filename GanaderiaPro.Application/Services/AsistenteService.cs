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

    // RC-04: preguntas frecuentes genéricas, válidas para cualquier rancho (no
    // nombran un animal ni un corral). Las consultas sobre un animal o un
    // corral concreto se escriben en la caja de texto.
    public static readonly IReadOnlyList<string> Ejemplos =
    [
        "¿Cuántos animales hay registrados?",
        "¿Cuántos machos hay?",
        "¿Cuántas hembras hay?",
        "¿Cuántos animales hay por raza?",
        "¿Cuántos animales hay en cada corral?",
        "¿Cuál es el peso promedio?",
        "¿Cuántas vacunaciones pendientes hay?",
        "¿Cuántas están próximas a parir?",
    ];

    private enum Agrupacion { Ninguna, Raza, Corral }

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

        // RC-05: «¿Cuántos animales hay en cada corral?» reparte por corral; no
        // es la cantidad de corrales.
        var agrupacion = pregunta.Contiene("por raza", "cada raza", "segun raza", "segun la raza") ? Agrupacion.Raza
            : pregunta.Contiene("cada corral", "por corral", "los corrales", "segun corral", "segun el corral") ? Agrupacion.Corral
            : Agrupacion.Ninguna;

        if (agrupacion == Agrupacion.Ninguna && pregunta.Contiene("cuant") && pregunta.ContienePalabras("corrales"))
        {
            if (!PuedeVer(Modulo.Corrales, out var denegada)) return denegada;
            var corrales = (await _corralRepository.ListarAsync(ranchoId, incluirInactivos: false)).Count;
            return Respuesta(corrales == 1 ? "Hay 1 corral activo." : $"Hay {corrales} corrales activos.");
        }

        if (pregunta.Contiene("cuant"))
        {
            if (!PuedeVer(Modulo.Ganado, out var denegada)) return denegada;
            if (agrupacion == Agrupacion.Corral && !PuedeVer(Modulo.Corrales, out denegada)) return denegada;
            return await ConteoAsync(pregunta, agrupacion);
        }

        return NoReconocida();
    }

    // ---- Cantidades (animales por corral, sexo, raza o estado)

    private async Task<RespuestaAsistenteResponse> ConteoAsync(PreguntaAsistente pregunta, Agrupacion agrupacion)
    {
        var estado = pregunta.Contiene("vend") ? EstadoAnimal.Vendido
            : pregunta.Contiene("fallec", "muert", "murieron") ? EstadoAnimal.Fallecido
            : EstadoAnimal.Activo;
        SexoAnimal? sexo = PalabrasHembra.Any(pregunta.ContienePalabras) ? SexoAnimal.Hembra
            : PalabrasMacho.Any(pregunta.ContienePalabras) ? SexoAnimal.Macho
            : null;

        var animales = await _animalRepository.BuscarAsync(_currentUser.RanchoId, null, estado, sexo, null);

        // Al repartir por corral no se filtra por uno: se muestran todos.
        var corral = agrupacion == Agrupacion.Corral ? (null, null) : await BuscarCorralAsync(pregunta);
        if (corral.Problema is { } problema)
        {
            return Respuesta(problema);
        }

        if (corral.Corral is { } c)
        {
            animales = animales.Where(a => a.CorralId == c.Id).ToList();
        }

        var raza = agrupacion == Agrupacion.Raza ? null : animales.Select(a => a.Raza)
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
        var detalle = (raza is null ? string.Empty : $" de raza {raza}") +
                      (corral.Corral is null ? string.Empty : $" en el corral «{corral.Corral.Nombre}»");

        return agrupacion switch
        {
            Agrupacion.Raza => Lista(
                $"{Describir(sexo, estado, plural: true, mayuscula: true)}{detalle} por raza ({cantidad} en total):",
                animales.GroupBy(a => a.Raza, StringComparer.OrdinalIgnoreCase)
                    .OrderByDescending(g => g.Count()).ThenBy(g => g.Key)
                    .Select(g => (g.Key, g.Count()))),
            Agrupacion.Corral => await PorCorralAsync(animales, sexo, estado, detalle),
            _ => Respuesta($"Hay {cantidad} {Describir(sexo, estado, plural: cantidad != 1)}{detalle}."),
        };
    }

    // RC-05: una línea por corral activo (también los vacíos) y los que no
    // están en ningún corral.
    private async Task<RespuestaAsistenteResponse> PorCorralAsync(
        IReadOnlyList<Animal> animales, SexoAnimal? sexo, EstadoAnimal estado, string detalle)
    {
        var corrales = await _corralRepository.ListarAsync(_currentUser.RanchoId, incluirInactivos: false);
        var lineas = corrales
            .Select(c => (c.Nombre, animales.Count(a => a.CorralId == c.Id)))
            .OrderByDescending(l => l.Item2).ThenBy(l => l.Nombre)
            .ToList();
        var sinCorral = animales.Count(a => a.CorralId is null || corrales.All(c => c.Id != a.CorralId));
        if (sinCorral > 0)
        {
            lineas.Add(("Sin corral", sinCorral));
        }

        return Lista($"{Describir(sexo, estado, plural: true, mayuscula: true)}{detalle} por corral ({animales.Count} en total):", lineas);
    }

    // «hembra activa», «machos vendidos», «animales fallecidos»…
    private static string Describir(SexoAnimal? sexo, EstadoAnimal estado, bool plural, bool mayuscula = false)
    {
        var sustantivo = (sexo, plural) switch
        {
            (SexoAnimal.Hembra, false) => "hembra",
            (SexoAnimal.Hembra, true) => "hembras",
            (SexoAnimal.Macho, false) => "macho",
            (SexoAnimal.Macho, true) => "machos",
            (_, false) => "animal",
            _ => "animales",
        };
        var femenino = sexo == SexoAnimal.Hembra;
        var adjetivo = estado switch
        {
            EstadoAnimal.Vendido => femenino ? "vendida" : "vendido",
            EstadoAnimal.Fallecido => femenino ? "fallecida" : "fallecido",
            _ => femenino ? "activa" : "activo",
        } + (plural ? "s" : string.Empty);
        var texto = $"{sustantivo} {adjetivo}";
        return mayuscula ? char.ToUpperInvariant(texto[0]) + texto[1..] : texto;
    }

    private static RespuestaAsistenteResponse Lista(string titulo, IEnumerable<(string Nombre, int Cantidad)> lineas)
    {
        var filas = lineas.Select(l => $"• {l.Nombre}: {l.Cantidad}").ToList();
        return Respuesta(filas.Count == 0 ? $"{titulo}\nNo hay animales registrados." : $"{titulo}\n{string.Join('\n', filas)}");
    }

    // RC-06: reconoce el corral aunque se escriba distinto: «corral cuatro»,
    // «corral 4», «el corral Corral 4», sin tildes o con un error de tipeo.
    // Problema: el mensaje para el usuario si no lo encontró o si hay dudas.
    private async Task<(Corral? Corral, string? Problema)> BuscarCorralAsync(PreguntaAsistente pregunta)
    {
        var palabras = pregunta.Palabras;
        var indice = palabras.ToList().IndexOf("corral");
        if (indice < 0)
        {
            return (null, null);
        }

        var corrales = await _corralRepository.ListarAsync(_currentUser.RanchoId, incluirInactivos: false);

        // 1) El nombre completo aparece tal cual en la pregunta.
        var encontrado = corrales
            .Where(c => pregunta.ContienePalabras(c.Nombre) || pregunta.ContienePalabras($"corral {c.Nombre}"))
            .OrderByDescending(c => c.Nombre.Length)
            .FirstOrDefault();

        if (encontrado is not null)
        {
            return (encontrado, null);
        }

        // 2) Lo escrito después de «corral» coincide con el nombre, con los
        // números en cifras y aceptando una letra de diferencia.
        var escrito = pregunta.DespuesDeCorral();
        var parecidos = corrales
            .Select(c => (Corral: c, Clave: PreguntaAsistente.ClaveCorral(c.Nombre)))
            .Where(x => x.Clave.Count > 0 && escrito.Count >= x.Clave.Count)
            .Select(x => (x.Corral, Distancia: PreguntaAsistente.Distancia(
                string.Join(' ', escrito.Take(x.Clave.Count)), string.Join(' ', x.Clave)), Largo: string.Join(' ', x.Clave).Length))
            .Where(x => x.Distancia == 0 || (x.Distancia == 1 && x.Largo >= 4))
            .ToList();
        var mejores = parecidos.Where(x => x.Distancia == parecidos.Min(p => p.Distancia)).Select(x => x.Corral).ToList();
        if (mejores.Count == 1)
        {
            return (mejores[0], null);
        }

        // Dos corrales igual de parecidos («oeste» → «Este» y «Oseste»): no
        // adivina, pide el nombre exacto.
        if (mejores.Count > 1)
        {
            var opciones = string.Join(" o ", mejores.OrderBy(c => c.Nombre).Select(c => $"«{c.Nombre}»"));
            return (null, $"¿Te referís al corral {opciones}? Escribí el nombre exacto.");
        }

        var siguiente = indice + 1 < palabras.Count ? palabras[indice + 1] : null;
        return siguiente is null || siguiente is "hay" or "tiene" or "tienen"
            ? (null, null)
            : (null, $"No encontré el corral «{siguiente}». Revisá el nombre en el módulo Corrales.");
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
        if (corral.Problema is { } problema)
        {
            return Respuesta(problema);
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
