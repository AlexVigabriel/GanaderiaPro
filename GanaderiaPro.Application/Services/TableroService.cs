using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Services;

// HU-12: indicadores del tablero. Patrón Facade: junta en una sola llamada
// datos de Ganado, Sanidad, Reproducción y Corrales. Solo lee.
public class TableroService : ITableroService
{
    // RN-10: «próxima a parir» = parto probable dentro de los próximos 30 días.
    private const int DiasProximasAParir = 30;

    private readonly IAnimalRepository _animalRepository;
    private readonly IVacunacionRepository _vacunacionRepository;
    private readonly IPrenezRepository _prenezRepository;
    private readonly ICorralRepository _corralRepository;
    private readonly ICurrentUserContext _currentUser;

    public TableroService(
        IAnimalRepository animalRepository,
        IVacunacionRepository vacunacionRepository,
        IPrenezRepository prenezRepository,
        ICorralRepository corralRepository,
        ICurrentUserContext currentUser)
    {
        _animalRepository = animalRepository;
        _vacunacionRepository = vacunacionRepository;
        _prenezRepository = prenezRepository;
        _corralRepository = corralRepository;
        _currentUser = currentUser;
    }

    public async Task<TableroResumenResponse> ObtenerResumenAsync()
    {
        var ranchoId = _currentUser.RanchoId;
        var hoy = FechaRancho.Hoy();

        // Las consultas van en secuencia: comparten el mismo DbContext.
        var conteos = await _animalRepository.ContarPorEstadoYSexoAsync(ranchoId);
        var vacunaciones = await _vacunacionRepository.ListarDeActivosAsync(ranchoId);
        var preneces = await _prenezRepository.ListarAbiertasConPartoHastaAsync(ranchoId, hoy.AddDays(DiasProximasAParir));
        var fallecidos = await _animalRepository.ContarFallecidosDesdeAsync(ranchoId, new DateOnly(hoy.Year, 1, 1));
        var corrales = await _corralRepository.ListarAsync(ranchoId, incluirInactivos: false);

        // RN-04: los conteos de animales consideran solo los Activos.
        int Activos(SexoAnimal? sexo) => conteos
            .Where(c => c.Estado == EstadoAnimal.Activo && (sexo is null || c.Sexo == sexo))
            .Sum(c => c.Cantidad);

        return new TableroResumenResponse(
            AnimalesActivos: Activos(null),
            MachosActivos: Activos(SexoAnimal.Macho),
            HembrasActivas: Activos(SexoAnimal.Hembra),
            Vacunados: vacunaciones.Select(v => v.AnimalId).Distinct().Count(),
            // RN-09: mismo cálculo que el módulo Sanidad (HU-27).
            VacunacionesPendientes: PendientesSanidad.Calcular(vacunaciones).Count,
            // Igual que HU-56: incluye partos probables ya vencidos sin registrar.
            ProximasAParir: preneces.Count,
            FallecidosDelAnio: fallecidos,
            CorralesActivos: corrales.Count);
    }
}
