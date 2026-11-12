using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

public interface IAsistenteService
{
    Task<RespuestaAsistenteResponse> ConsultarAsync(string? pregunta);
}
