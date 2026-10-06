using System.Reflection;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;

namespace GanaderiaPro.Api.Permisos;

// HU-34: control central de permisos. Consultar (GET) exige Lectura sobre el
// módulo; crear, editar o borrar exige Escritura. Si no alcanza, 403.
// Se valida en el servidor: ocultar botones en la app no alcanza.
public class PermisoPorModuloFilter : IAsyncAuthorizationFilter
{
    public const string MensajeSinAcceso = "No tienes permiso para acceder a este módulo.";
    public const string MensajeSoloLectura = "Tu rol solo permite consultar este módulo.";

    public Task OnAuthorizationAsync(AuthorizationFilterContext context)
    {
        if (context.ActionDescriptor is not ControllerActionDescriptor accion)
        {
            return Task.CompletedTask;
        }

        // Públicos (login, registro, invitación) y pedidos sin sesión: de eso
        // se ocupa la autenticación, que responde 401.
        if (EsPublica(accion) || context.HttpContext.User.Identity?.IsAuthenticated != true)
        {
            return Task.CompletedTask;
        }

        if (accion.MethodInfo.IsDefined(typeof(SinModuloAttribute)))
        {
            return Task.CompletedTask;
        }

        var modulo = ModuloDe(accion);
        var valorRol = context.HttpContext.User.FindFirst("rol")?.Value;

        // Por seguridad, una acción sin módulo o un token sin rol se rechazan.
        if (modulo is null || !Enum.TryParse<RolUsuario>(valorRol, out var rol))
        {
            context.Result = Prohibido(MensajeSinAcceso);
            return Task.CompletedTask;
        }

        var requerido = HttpMethods.IsGet(context.HttpContext.Request.Method) || HttpMethods.IsHead(context.HttpContext.Request.Method)
            ? NivelAcceso.Lectura
            : NivelAcceso.Escritura;

        if (!MatrizPermisos.Permite(rol, modulo.Value, requerido))
        {
            var tieneLectura = MatrizPermisos.Permite(rol, modulo.Value, NivelAcceso.Lectura);
            context.Result = Prohibido(tieneLectura ? MensajeSoloLectura : MensajeSinAcceso);
        }

        return Task.CompletedTask;
    }

    public static bool EsPublica(ControllerActionDescriptor accion) =>
        accion.MethodInfo.IsDefined(typeof(AllowAnonymousAttribute)) ||
        (accion.ControllerTypeInfo.IsDefined(typeof(AllowAnonymousAttribute)) &&
         !accion.MethodInfo.IsDefined(typeof(AuthorizeAttribute)));

    // El módulo de la acción manda sobre el de su controlador.
    public static Modulo? ModuloDe(ControllerActionDescriptor accion) =>
        (accion.MethodInfo.GetCustomAttribute<ModuloAttribute>() ??
         accion.ControllerTypeInfo.GetCustomAttribute<ModuloAttribute>())?.Modulo;

    private static ObjectResult Prohibido(string mensaje) =>
        new(new { mensaje }) { StatusCode = StatusCodes.Status403Forbidden };
}
