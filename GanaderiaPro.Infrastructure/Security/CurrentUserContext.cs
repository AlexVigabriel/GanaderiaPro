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
}
