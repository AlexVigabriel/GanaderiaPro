using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Exceptions;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-56: preñez y parto de las hembras (RN-10). RC-10: diagnóstico de preñez y aborto.
public class PrenezService : IPrenezService
{
    private readonly IPrenezRepository _prenezRepository;
    private readonly IAnimalRepository _animalRepository;
    private readonly ICurrentUserContext _currentUser;
    private readonly IUnitOfWork _unitOfWork;

    public PrenezService(
        IPrenezRepository prenezRepository,
        IAnimalRepository animalRepository,
        ICurrentUserContext currentUser,
        IUnitOfWork unitOfWork)
    {
        _prenezRepository = prenezRepository;
        _animalRepository = animalRepository;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
    }

    // De la más reciente a la más antigua.
    public async Task<IReadOnlyList<PrenezResponse>> ListarAsync(Guid animalId)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        var preneces = await _prenezRepository.ListarPorAnimalAsync(animal.Id);
        return preneces.Select(ToResponse).ToList();
    }

    public async Task<PrenezResponse> RegistrarServicioAsync(Guid animalId, RegistrarServicioRequest request)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        ValidarHembraActiva(animal);

        // RN-14: no se registran fechas futuras.
        if (request.FechaServicio > FechaRancho.Hoy())
        {
            throw new ReglaDeNegocioException("La fecha de servicio no puede ser futura.");
        }

        if (animal.FechaNacimiento is { } nacimiento && request.FechaServicio < nacimiento)
        {
            throw new ReglaDeNegocioException("La fecha de servicio no puede ser anterior al nacimiento.");
        }

        // RC-07: la observación tiene que describir algo, no ser solo un número.
        if (TextoDescriptivo.Validar(request.Observacion, 500) is { } errorObservacion)
        {
            throw new ReglaDeNegocioException(errorObservacion);
        }

        var anteriores = await _prenezRepository.ListarPorAnimalAsync(animal.Id);
        if (anteriores.Any(p => p.Abierta))
        {
            throw new ReglaDeNegocioException(
                "Esta hembra ya tiene una preñez abierta: registrá el parto, el aborto o el diagnóstico «Vacía» antes de un nuevo servicio.");
        }

        // RC-10: tras un parto o un aborto hay que esperar antes de un nuevo servicio.
        var ultima = anteriores
            .Where(p => p.ServicioPosibleDesde is not null)
            .MaxBy(p => p.ServicioPosibleDesde);
        if (ultima?.ServicioPosibleDesde is { } desde && request.FechaServicio < desde)
        {
            throw new ReglaDeNegocioException(ultima.Estado switch
            {
                EstadoPrenez.Parto =>
                    $"Después del parto del {ultima.FechaParto:dd/MM/yyyy} el útero necesita {Prenez.EsperaTrasParto} días para recuperarse: el nuevo servicio se registra desde el {desde:dd/MM/yyyy}.",
                EstadoPrenez.Aborto =>
                    $"Después del aborto del {ultima.FechaAborto:dd/MM/yyyy} hay que esperar al menos un ciclo de celo ({Prenez.EsperaTrasAborto} días): el nuevo servicio se registra desde el {desde:dd/MM/yyyy}.",
                _ => $"La fecha de servicio no puede ser anterior al diagnóstico «Vacía» del {desde:dd/MM/yyyy}.",
            });
        }

        var prenez = new Prenez
        {
            Id = Guid.NewGuid(),
            AnimalId = animal.Id,
            FechaServicio = request.FechaServicio,
            FechaProbableParto = Prenez.CalcularFechaProbableParto(request.FechaServicio),
            Observacion = string.IsNullOrWhiteSpace(request.Observacion) ? null : request.Observacion.Trim(),
            FechaRegistro = DateTime.UtcNow,
            RegistradoPorId = _currentUser.UsuarioId,
        };

        _prenezRepository.Agregar(prenez);
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(prenez);
    }

    // Registrar el parto cierra la preñez: deja de contarse como próxima a parir.
    public async Task<PrenezResponse> RegistrarPartoAsync(Guid animalId, Guid prenezId, RegistrarPartoRequest request)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        ValidarHembraActiva(animal);

        var prenez = await ObtenerAbiertaAsync(animal, prenezId);
        ValidarFecha(prenez, request.FechaParto, "del parto");

        // RC-10: antes de los 260 días no es parto sino aborto.
        if (request.FechaParto < prenez.PartoDesde)
        {
            throw new ReglaDeNegocioException(
                $"El parto se registra desde los {Prenez.DiasMinimosParto} días del servicio (desde el {prenez.PartoDesde:dd/MM/yyyy}); antes es un aborto.");
        }

        prenez.FechaParto = request.FechaParto;
        prenez.PartoRegistradoPorId = _currentUser.UsuarioId;
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(prenez);
    }

    // RC-10: «Confirmada» deja la preñez abierta; «Vacía» la cierra. Uno por preñez.
    public async Task<PrenezResponse> RegistrarDiagnosticoAsync(
        Guid animalId, Guid prenezId, RegistrarDiagnosticoPrenezRequest request)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        ValidarHembraActiva(animal);

        var prenez = await ObtenerAbiertaAsync(animal, prenezId);
        if (prenez.Diagnostico is not null)
        {
            throw new ReglaDeNegocioException("Esta preñez ya tiene el diagnóstico registrado.");
        }

        if (!Enum.IsDefined(request.Resultado))
        {
            throw new ReglaDeNegocioException("Elegí el resultado del diagnóstico: Confirmada o Vacía.");
        }

        ValidarFecha(prenez, request.Fecha, "del diagnóstico");

        // RC-10: antes de los 30 días no se puede detectar la preñez.
        if (request.Fecha < prenez.DiagnosticoDesde)
        {
            throw new ReglaDeNegocioException(
                $"El diagnóstico de preñez se hace desde los {Prenez.DiasMinimosDiagnostico} días del servicio (desde el {prenez.DiagnosticoDesde:dd/MM/yyyy}): antes no se detecta por ecografía ni palpación.");
        }

        prenez.Diagnostico = request.Resultado;
        prenez.FechaDiagnostico = request.Fecha;
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(prenez);
    }

    // RC-10: el aborto cierra la preñez.
    public async Task<PrenezResponse> RegistrarAbortoAsync(Guid animalId, Guid prenezId, RegistrarAbortoRequest request)
    {
        var animal = await ObtenerAnimalDelRanchoAsync(animalId);
        ValidarHembraActiva(animal);

        var prenez = await ObtenerAbiertaAsync(animal, prenezId);

        // RC-10: si la preñez se confirmó después del día 259, ya no queda ninguna fecha posible de aborto.
        if (prenez.FechaDiagnostico is { } diagnostico && diagnostico > prenez.AbortoHasta)
        {
            throw new ReglaDeNegocioException(
                $"Ya no se puede registrar un aborto: el diagnóstico es del {diagnostico:dd/MM/yyyy} y el aborto solo se registra hasta los {Prenez.DiasMinimosParto - 1} días del servicio ({prenez.AbortoHasta:dd/MM/yyyy}). Si perdió la cría, registralo como parto.");
        }

        ValidarFecha(prenez, request.Fecha, "del aborto");

        // RC-10: el aborto es la pérdida entre los 42 y los 259 días.
        if (request.Fecha < prenez.AbortoDesde)
        {
            throw new ReglaDeNegocioException(
                $"Antes de los {Prenez.DiasMinimosAborto} días del servicio es muerte embrionaria, no aborto: se registra desde el {prenez.AbortoDesde:dd/MM/yyyy}. Si la vaca no quedó preñada, registrá el diagnóstico «Vacía».");
        }

        if (request.Fecha > prenez.AbortoHasta)
        {
            throw new ReglaDeNegocioException(
                $"Desde los {Prenez.DiasMinimosParto} días del servicio ya no es aborto sino parto (prematuro): registralo como parto.");
        }

        prenez.FechaAborto = request.Fecha;
        await _unitOfWork.GuardarCambiosAsync();

        return ToResponse(prenez);
    }

    private async Task<Prenez> ObtenerAbiertaAsync(Animal animal, Guid prenezId)
    {
        var prenez = await _prenezRepository.ObtenerPorIdAsync(animal.Id, prenezId)
            ?? throw new RecursoNoEncontradoException("No se encontró la preñez.");

        if (!prenez.Abierta)
        {
            throw new ReglaDeNegocioException(prenez.Estado switch
            {
                EstadoPrenez.Parto => "Esta preñez ya tiene el parto registrado.",
                EstadoPrenez.Aborto => "Esta preñez ya se cerró con un aborto.",
                _ => "Esta preñez ya se cerró con el diagnóstico «Vacía».",
            });
        }

        return prenez;
    }

    // RN-14 y RC-10: ni futura, ni antes del servicio, ni antes del diagnóstico.
    private static void ValidarFecha(Prenez prenez, DateOnly fecha, string deQue)
    {
        if (fecha > FechaRancho.Hoy())
        {
            throw new ReglaDeNegocioException($"La fecha {deQue} no puede ser futura.");
        }

        if (fecha < prenez.FechaServicio)
        {
            throw new ReglaDeNegocioException($"La fecha {deQue} no puede ser anterior al servicio.");
        }

        if (prenez.FechaDiagnostico is { } diagnostico && fecha < diagnostico)
        {
            throw new ReglaDeNegocioException($"La fecha {deQue} no puede ser anterior al diagnóstico de preñez.");
        }
    }

    // RN-10: «próxima a parir» = parto probable dentro de los próximos días.
    // También incluye los partos probables ya vencidos que no se registraron.
    public async Task<IReadOnlyList<ProximaAParirResponse>> ListarProximasAParirAsync(int dias = 30)
    {
        var hoy = FechaRancho.Hoy();
        var preneces = await _prenezRepository.ListarAbiertasConPartoHastaAsync(_currentUser.RanchoId, hoy.AddDays(dias));
        return preneces
            .Select(p => new ProximaAParirResponse(
                p.AnimalId,
                p.Animal!.Arete,
                p.Animal.Nombre,
                p.FechaProbableParto,
                p.FechaProbableParto.DayNumber - hoy.DayNumber))
            .ToList();
    }

    private static void ValidarHembraActiva(Animal animal)
    {
        if (animal.Sexo != SexoAnimal.Hembra)
        {
            throw new ReglaDeNegocioException("Solo se puede registrar la preñez de una hembra.");
        }

        if (animal.Estado != EstadoAnimal.Activo)
        {
            throw new ReglaDeNegocioException("Solo se puede registrar la preñez de animales activos.");
        }
    }

    // RN-16: el animal se busca siempre dentro del rancho del usuario actual.
    private async Task<Animal> ObtenerAnimalDelRanchoAsync(Guid animalId) =>
        await _animalRepository.ObtenerPorIdAsync(_currentUser.RanchoId, animalId)
            ?? throw new RecursoNoEncontradoException("No se encontró el animal.");

    private static PrenezResponse ToResponse(Prenez p) =>
        new(p.Id, p.FechaServicio, p.FechaProbableParto, p.FechaParto, p.Abierta, p.Observacion, p.Estado,
            p.Diagnostico, p.FechaDiagnostico, p.FechaAborto);
}
