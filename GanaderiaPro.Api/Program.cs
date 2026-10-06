using System.Security.Claims;
using System.Text;
using System.Text.Json.Serialization;
using GanaderiaPro.Api.Permisos;
using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Infrastructure;
using GanaderiaPro.Infrastructure.Persistence;
using GanaderiaPro.Infrastructure.Planes;
using GanaderiaPro.Infrastructure.Repositories;
using GanaderiaPro.Infrastructure.Security;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

// HU-34: cada pedido pasa por el control de permisos por módulo.
builder.Services.AddControllers(options => options.Filters.Add<PermisoPorModuloFilter>())
    .AddJsonOptions(options => options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

builder.Services.AddDbContext<GanaderiaProDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Solo para desarrollo local: permite que la app Flutter (que corre en otro
// puerto) llame a esta API desde el navegador sin que CORS la bloquee.
const string PoliticaCorsDesarrollo = "DesarrolloFlutter";
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddCors(options =>
        options.AddPolicy(PoliticaCorsDesarrollo, policy =>
            policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));
}

builder.Services.AddHttpContextAccessor();

builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
builder.Services.AddScoped<IAnimalRepository, AnimalRepository>();
builder.Services.AddScoped<IAnimalService, AnimalService>();
builder.Services.AddScoped<IPesajeRepository, PesajeRepository>();
builder.Services.AddScoped<IPesajeService, PesajeService>();
builder.Services.AddScoped<IVacunacionRepository, VacunacionRepository>();
builder.Services.AddScoped<IVacunacionService, VacunacionService>();
builder.Services.AddScoped<ISanidadService, SanidadService>();
builder.Services.AddScoped<ICorralRepository, CorralRepository>();
builder.Services.AddScoped<ICorralService, CorralService>();
builder.Services.AddScoped<IInvitacionRepository, InvitacionRepository>();
builder.Services.AddScoped<IColaboradorService, ColaboradorService>();
builder.Services.AddScoped<IInvitacionService, InvitacionService>();
builder.Services.AddScoped<ILimitesPlanProvider, LimitesPlanProvider>();
builder.Services.AddScoped<IControlLimitesPlan, ControlLimitesPlan>();
builder.Services.AddScoped<IUsuarioRepository, UsuarioRepository>();
builder.Services.AddScoped<IRanchoRepository, RanchoRepository>();
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<ITokenGenerator, TokenGenerator>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ICurrentUserContext, CurrentUserContext>();

var claveJwt = builder.Configuration["Jwt:SigningKey"]
    ?? throw new InvalidOperationException(
        "Falta configurar Jwt:SigningKey. Ejecutar: dotnet user-secrets set \"Jwt:SigningKey\" \"<clave larga>\" --project GanaderiaPro.Api");

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(claveJwt)),
            ValidateIssuer = false,
            ValidateAudience = false,
            ValidateLifetime = true,
        };

        // HU-52: un token válido en firma y vencimiento igual se rechaza si
        // el usuario ya cerró sesión (su versión de sesión cambió).
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = async contexto =>
            {
                var usuario = contexto.Principal;
                var id = usuario?.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? usuario?.FindFirst("sub")?.Value;
                var version = usuario?.FindFirst(ClaimSesion.Version)?.Value ?? "0";
                var authService = contexto.HttpContext.RequestServices.GetRequiredService<IAuthService>();

                if (!Guid.TryParse(id, out var usuarioId) ||
                    !int.TryParse(version, out var versionDelToken) ||
                    !await authService.SesionVigenteAsync(usuarioId, versionDelToken))
                {
                    contexto.Fail("La sesión fue cerrada.");
                }
            },
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseCors(PoliticaCorsDesarrollo);
}

app.UseHttpsRedirection();

// Las respuestas de la API nunca deben quedar en caché del navegador — sin
// esto, el navegador puede mostrar datos viejos después de editar/eliminar
// aunque el servidor ya haya guardado el cambio.
app.Use(async (context, next) =>
{
    context.Response.Headers.CacheControl = "no-store, no-cache, must-revalidate";
    await next();
});

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
