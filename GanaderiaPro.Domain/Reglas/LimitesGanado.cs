namespace GanaderiaPro.Domain.Reglas;

// RC-01 a RC-03 (correcciones del Sprint 3): límites de edad y peso con
// fundamento. Las fuentes están en GanaderiaPro_Requisitos_Correccion_Sprint3.
public static class LimitesGanado
{
    // RC-01: los terneros nacen con unos 19 kg (Jersey) a 52 kg (Holstein);
    // Nelore y Brahman del trópico boliviano, 30 a 38 kg. Se deja margen para
    // mellizos, prematuros y terneros grandes.
    public const decimal PesoNacimientoMinimoKg = 15;
    public const decimal PesoNacimientoMaximoKg = 60;

    // RC-02: la vida de un bovino llega a unos 20 años; la vida productiva de
    // las razas comerciales es de 8 a 15. Más de 15 se acepta con un aviso.
    public const int EdadMaximaAnios = 20;
    public const int EdadAvisoAnios = 15;

    // RC-03: el peso actual no baja del mínimo al nacer y, como máximo, es el
    // peso al nacer más alto más 2 kg por día de vida. La ganancia más alta
    // publicada es 1,97 kg/día (engorde a corral); el tope es el de toros de
    // razas grandes.
    public const decimal PesoMinimoKg = PesoNacimientoMinimoKg;
    public const decimal GananciaMaximaDiariaKg = 2;
    public const decimal PesoMaximoKg = 1500;

    // Peso más alto posible para un animal nacido en «nacimiento», a la fecha
    // «fecha». Sin fecha de nacimiento solo se aplica el tope general.
    public static decimal PesoMaximoParaEdad(DateOnly? nacimiento, DateOnly fecha)
    {
        if (nacimiento is not { } n)
        {
            return PesoMaximoKg;
        }

        var dias = Math.Max(0, fecha.DayNumber - n.DayNumber);
        return Math.Min(PesoMaximoKg, PesoNacimientoMaximoKg + GananciaMaximaDiariaKg * dias);
    }

    // Devuelve el problema del peso o null si es válido.
    public static string? ValidarPeso(decimal peso, DateOnly? nacimiento, DateOnly fecha, string que = "El peso")
    {
        var maximo = PesoMaximoParaEdad(nacimiento, fecha);
        if (peso >= PesoMinimoKg && peso <= maximo)
        {
            return null;
        }

        return maximo < PesoMaximoKg
            ? $"{que} debe estar entre {PesoMinimoKg} y {maximo:0.##} kg para un animal de {DescribirEdad(nacimiento!.Value, fecha)}."
            : $"{que} debe estar entre {PesoMinimoKg} y {PesoMaximoKg} kg.";
    }

    public static string DescribirEdad(DateOnly nacimiento, DateOnly fecha)
    {
        var dias = Math.Max(0, fecha.DayNumber - nacimiento.DayNumber);
        if (dias < 60)
        {
            return dias == 1 ? "1 día" : $"{dias} días";
        }

        var meses = (fecha.Year - nacimiento.Year) * 12 + fecha.Month - nacimiento.Month - (fecha.Day < nacimiento.Day ? 1 : 0);
        return meses == 1 ? "1 mes" : $"{meses} meses";
    }
}
