using System.Security.Claims;
using GanaderiaPro.Application.Interfaces;
using Microsoft.AspNetCore.Http;

namespace GanaderiaPro.Infrastructure.Security;

public class CurrentUserContext : ICurrentUserContext
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserContext(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public Guid RanchoId
    {
        get
        {
            var valor = _httpContextAccessor.HttpContext?.User.FindFirst("ranchoId")?.Value
                ?? throw new InvalidOperationException("No hay un usuario autenticado con RanchoId.");

            return Guid.Parse(valor);
        }
    }

    public Guid UsuarioId
    {
        get
        {
            // El "sub" del token llega como NameIdentifier (mapeo de ASP.NET).
            var usuario = _httpContextAccessor.HttpContext?.User;
            var valor = usuario?.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? usuario?.FindFirst("sub")?.Value
                ?? throw new InvalidOperationException("No hay un usuario autenticado.");

            return Guid.Parse(valor);
        }
    }
}
