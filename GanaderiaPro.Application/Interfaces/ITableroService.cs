using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface ITableroService
{
    Task<TableroResumenResponse> ObtenerResumenAsync();
}
