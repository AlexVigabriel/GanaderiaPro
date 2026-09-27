using System.Text.Json.Serialization;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Application.Services;
using GanaderiaPro.Infrastructure;
using GanaderiaPro.Infrastructure.Persistence;
using GanaderiaPro.Infrastructure.Repositories;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers()
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

builder.Services.AddScoped<IAnimalRepository, AnimalRepository>();
builder.Services.AddScoped<IAnimalService, AnimalService>();

// TODO: reemplazar por el ICurrentUserContext real cuando exista login (JWT) — Choquecallata, HU-07/HU-09.
builder.Services.AddScoped<ICurrentUserContext, StubCurrentUserContext>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseCors(PoliticaCorsDesarrollo);

    using var scope = app.Services.CreateScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<GanaderiaProDbContext>();
    await DevDataSeeder.SembrarRanchoDePruebaAsync(dbContext);
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
