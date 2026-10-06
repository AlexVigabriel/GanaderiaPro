using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GanaderiaPro.Api.Controllers;

// HU-46: la app pregunta cada pocos segundos si el servidor responde, para
// mostrar "Sin conexión". Es público y no devuelve ningún dato.
[ApiController]
[Route("api/salud")]
[AllowAnonymous]
public class SaludController : ControllerBase
{
    [HttpGet]
    public IActionResult Verificar() => NoContent();
}
