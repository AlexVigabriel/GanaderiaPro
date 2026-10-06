using System.Reflection;
using System.Security.Claims;
using GanaderiaPro.Api.Controllers;
using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Domain.Entities;
using GanaderiaPro.Domain.Permisos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Xunit;

namespace GanaderiaPro.Tests;

// HU-34: la matriz de permisos (backlog, sección 5).
public class MatrizPermisosTests
{
    [Theory]
    // Ganado (alta, edición, baja)
    [InlineData(RolUsuario.Propietario, Modulo.Ganado, NivelAcceso.Escritura)]
    [InlineData(RolUsuario.Socio, Modulo.Ganado, NivelAcceso.Lectura)]
    [InlineData(RolUsuario.Veterinario, Modulo.Ganado, NivelAcceso.Lectura)]
    [InlineData(RolUsuario.EncargadoCorrales, Modulo.Ganado, NivelAcceso.Lectura)]
    [InlineData(RolUsuario.EncargadoIngreso, Modulo.Ganado, NivelAcceso.Escritura)]
    // Pesaje
    [InlineData(RolUsuario.Propietario, Modulo.Pesaje, NivelAcceso.Escritura)]
    [InlineData(RolUsuario.Socio, Modulo.Pesaje, NivelAcceso.Lectura)]
    [InlineData(RolUsuario.Veterinario, Modulo.Pesaje, NivelAcceso.Escritura)]
    [InlineData(RolUsuario.EncargadoCorrales, Modulo.Pesaje, NivelAcceso.Escritura)]
    [InlineData(RolUsuario.EncargadoIngreso, Modulo.Pesaje, NivelAcceso.Escritura)]
    // Corrales
    [InlineData(RolUsuario.Propietario, Modulo.Corrales, NivelAcceso.Escritura)]
    [InlineData(RolUsuario.Socio, Modulo.Corrales, NivelAcceso.Lectura)]
    [InlineData(RolUsuario.Veterinario, Modulo.Corrales, NivelAcceso.Lectura)]
    [InlineData(RolUsuario.EncargadoCorrales, Modulo.Corrales, NivelAcceso.Escritura)]
    [InlineData(RolUsuario.EncargadoIngreso, Modulo.Corrales, NivelAcceso.Lectura)]
    // Sanidad
    [InlineData(RolUsuario.Propietario, Modulo.Sanidad, NivelAcceso.Escritura)]
    [InlineData(RolUsuario.Socio, Modulo.Sanidad, NivelAcceso.Lectura)]
    [InlineData(RolUsuario.Veterinario, Modulo.Sanidad, NivelAcceso.Escritura)]
    [InlineData(RolUsuario.EncargadoCorrales, Modulo.Sanidad, NivelAcceso.Lectura)]
    [InlineData(RolUsuario.EncargadoIngreso, Modulo.Sanidad, NivelAcceso.Lectura)]
    // Socios y colaboradores
    [InlineData(RolUsuario.Propietario, Modulo.Colaboradores, NivelAcceso.Escritura)]
    [InlineData(RolUsuario.Socio, Modulo.Colaboradores, NivelAcceso.Ninguno)]
    [InlineData(RolUsuario.Veterinario, Modulo.Colaboradores, NivelAcceso.Ninguno)]
    [InlineData(RolUsuario.EncargadoCorrales, Modulo.Colaboradores, NivelAcceso.Ninguno)]
    [InlineData(RolUsuario.EncargadoIngreso, Modulo.Colaboradores, NivelAcceso.Ninguno)]
    // Dashboard: solo lectura para todos
    [InlineData(RolUsuario.Propietario, Modulo.Tablero, NivelAcceso.Lectura)]
    [InlineData(RolUsuario.Veterinario, Modulo.Tablero, NivelAcceso.Lectura)]
    public void Acceso_CoincideConLaMatrizDelBacklog(RolUsuario rol, Modulo modulo, NivelAcceso esperado)
    {
        Assert.Equal(esperado, MatrizPermisos.Acceso(rol, modulo));
    }

    [Fact]
    public void PermisosDe_IncluyeTodosLosModulos()
    {
        var permisos = MatrizPermisos.PermisosDe(RolUsuario.Veterinario);

        Assert.Equal(Enum.GetValues<Modulo>().Length, permisos.Count);
    }
}

// HU-34: el control central responde 403 según el rol y el tipo de pedido.
public class PermisoPorModuloFilterTests
{
    private static AuthorizationFilterContext Contexto(Type controlador, string accion, string metodoHttp, RolUsuario? rol)
    {
        var http = new DefaultHttpContext();
        http.Request.Method = metodoHttp;
        if (rol is not null)
        {
            http.User = new ClaimsPrincipal(new ClaimsIdentity([new Claim("rol", rol.ToString()!)], "Bearer"));
        }

        var descriptor = new ControllerActionDescriptor
        {
            ControllerTypeInfo = controlador.GetTypeInfo(),
            MethodInfo = controlador.GetMethod(accion)!,
        };
        return new AuthorizationFilterContext(new ActionContext(http, new RouteData(), descriptor), []);
    }

    private static int? Ejecutar(Type controlador, string accion, string metodoHttp, RolUsuario? rol)
    {
        var contexto = Contexto(controlador, accion, metodoHttp, rol);
        new PermisoPorModuloFilter().OnAuthorizationAsync(contexto).GetAwaiter().GetResult();
        return (contexto.Result as ObjectResult)?.StatusCode;
    }

    [Theory]
    // Consultar con Lectura: pasa.
    [InlineData(typeof(CorralesController), nameof(CorralesController.Listar), "GET", RolUsuario.Veterinario, null)]
    // Modificar con solo Lectura: 403.
    [InlineData(typeof(CorralesController), nameof(CorralesController.Crear), "POST", RolUsuario.Veterinario, 403)]
    [InlineData(typeof(AnimalesController), nameof(AnimalesController.Eliminar), "DELETE", RolUsuario.EncargadoCorrales, 403)]
    // Modificar con Escritura: pasa.
    [InlineData(typeof(CorralesController), nameof(CorralesController.Crear), "POST", RolUsuario.EncargadoCorrales, null)]
    [InlineData(typeof(PesajesController), nameof(PesajesController.Registrar), "POST", RolUsuario.Veterinario, null)]
    [InlineData(typeof(VacunacionesController), nameof(VacunacionesController.Registrar), "POST", RolUsuario.Veterinario, null)]
    [InlineData(typeof(AnimalesController), nameof(AnimalesController.RegistrarLote), "POST", RolUsuario.EncargadoIngreso, null)]
    // Sin acceso al módulo: 403 aunque solo consulte.
    [InlineData(typeof(ColaboradoresController), nameof(ColaboradoresController.Listar), "GET", RolUsuario.Veterinario, 403)]
    // Mover un animal de corral es del módulo Corrales, no de Ganado.
    [InlineData(typeof(CorralesController), nameof(CorralesController.AsignarAnimal), "PUT", RolUsuario.EncargadoCorrales, null)]
    [InlineData(typeof(CorralesController), nameof(CorralesController.AsignarAnimal), "PUT", RolUsuario.EncargadoIngreso, 403)]
    // Cerrar sesión: cualquier usuario con sesión.
    [InlineData(typeof(AuthController), nameof(AuthController.CerrarSesion), "POST", RolUsuario.Veterinario, null)]
    // Públicos: no los toca.
    [InlineData(typeof(AuthController), nameof(AuthController.IniciarSesion), "POST", null, null)]
    [InlineData(typeof(InvitacionesController), nameof(InvitacionesController.Aceptar), "POST", null, null)]
    public void Responde403SoloCuandoElRolNoAlcanza(Type controlador, string accion, string metodo, RolUsuario? rol, int? esperado)
    {
        Assert.Equal(esperado, Ejecutar(controlador, accion, metodo, rol));
    }

    [Fact]
    public void ConSoloLectura_ElMensajeLoExplica()
    {
        var contexto = Contexto(typeof(SanidadController), nameof(SanidadController.ObtenerResumen), "POST", RolUsuario.EncargadoCorrales);
        new PermisoPorModuloFilter().OnAuthorizationAsync(contexto).GetAwaiter().GetResult();

        var cuerpo = Assert.IsType<ObjectResult>(contexto.Result).Value!;
        Assert.Equal(PermisoPorModuloFilter.MensajeSoloLectura, cuerpo.GetType().GetProperty("mensaje")!.GetValue(cuerpo));
    }

    [Fact]
    public void TokenSinRol_SeRechaza()
    {
        var http = new DefaultHttpContext();
        http.Request.Method = "GET";
        http.User = new ClaimsPrincipal(new ClaimsIdentity([new Claim("sub", "x")], "Bearer"));
        var descriptor = new ControllerActionDescriptor
        {
            ControllerTypeInfo = typeof(AnimalesController).GetTypeInfo(),
            MethodInfo = typeof(AnimalesController).GetMethod(nameof(AnimalesController.Buscar))!,
        };
        var contexto = new AuthorizationFilterContext(new ActionContext(http, new RouteData(), descriptor), []);

        new PermisoPorModuloFilter().OnAuthorizationAsync(contexto).GetAwaiter().GetResult();

        Assert.Equal(403, (contexto.Result as ObjectResult)?.StatusCode);
    }
}

// HU-34: red de seguridad. Si alguien agrega un endpoint y se olvida de
// indicar su módulo, esta prueba falla antes de que llegue a producción.
public class RedDeSeguridadPermisosTests
{
    [Fact]
    public void TodoEndpointConSesion_TieneModuloOEsExplicitamenteLibre()
    {
        var sinModulo = typeof(AnimalesController).Assembly.GetTypes()
            .Where(t => typeof(ControllerBase).IsAssignableFrom(t) && !t.IsAbstract)
            .SelectMany(t => t.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly)
                .Where(m => m.GetCustomAttributes().Any(a => a is Microsoft.AspNetCore.Mvc.Routing.HttpMethodAttribute))
                .Select(m => new ControllerActionDescriptor { ControllerTypeInfo = t.GetTypeInfo(), MethodInfo = m }))
            .Where(a => !PermisoPorModuloFilter.EsPublica(a))
            .Where(a => !a.MethodInfo.IsDefined(typeof(SinModuloAttribute)))
            .Where(a => PermisoPorModuloFilter.ModuloDe(a) is null)
            .Select(a => $"{a.ControllerTypeInfo.Name}.{a.MethodInfo.Name}")
            .ToList();

        Assert.True(sinModulo.Count == 0, "Endpoints sin módulo: " + string.Join(", ", sinModulo));
    }

    [Fact]
    public void LosEndpointsPublicosSonSoloLosEsperados()
    {
        var publicos = typeof(AnimalesController).Assembly.GetTypes()
            .Where(t => typeof(ControllerBase).IsAssignableFrom(t) && !t.IsAbstract)
            .SelectMany(t => t.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly)
                .Where(m => m.GetCustomAttributes().Any(a => a is Microsoft.AspNetCore.Mvc.Routing.HttpMethodAttribute))
                .Select(m => new ControllerActionDescriptor { ControllerTypeInfo = t.GetTypeInfo(), MethodInfo = m }))
            .Where(PermisoPorModuloFilter.EsPublica)
            .Select(a => $"{a.ControllerTypeInfo.Name}.{a.MethodInfo.Name}")
            .OrderBy(n => n)
            .ToList();

        Assert.Equal(
            new[] { "AuthController.IniciarSesion", "AuthController.Registrar", "InvitacionesController.Aceptar", "InvitacionesController.Obtener",
                "SaludController.Verificar" },
            publicos);
    }
}
