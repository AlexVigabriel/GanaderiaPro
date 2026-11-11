using GanaderiaPro.Application.DTOs;
using GanaderiaPro.Domain.Entities;

namespace GanaderiaPro.Application.Interfaces;

public interface IExcelGanadoService
{
    byte[] DescargarPlantilla();
    Task<byte[]> ExportarAsync(string? busqueda, EstadoAnimal? estado, SexoAnimal? sexo, string? raza, CategoriaAnimal? categoria);
    Task<ImportacionResponse> ImportarAsync(Stream archivo);
}
