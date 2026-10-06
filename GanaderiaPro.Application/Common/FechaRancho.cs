namespace GanaderiaPro.Application.Common;

// RN-14: "hoy" se calcula en la hora de Bolivia, no en UTC. Entre las 20:00
// y la medianoche la fecha UTC ya es la de mañana, y una fecha futura pasaba
// como válida. Lo usan todos los servicios que validan fechas.
public static class FechaRancho
{
    private static readonly TimeZoneInfo ZonaHoraria = TimeZoneInfo.FindSystemTimeZoneById("America/La_Paz");

    public static DateOnly Hoy() =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, ZonaHoraria));
}
