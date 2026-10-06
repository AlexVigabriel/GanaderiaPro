namespace GanaderiaPro.Application.DTOs;

// HU-55
public record RegistrarPesajeRequest(decimal Peso, DateOnly Fecha, string? Observacion = null);

public record PesajeResponse(Guid Id, DateOnly Fecha, decimal Peso, string? Observacion);

// Al registrar se devuelve también el peso actual del animal, que cambia
// solo si el pesaje es el más reciente.
public record RegistrarPesajeResponse(PesajeResponse Pesaje, decimal? PesoActualAnimal);
