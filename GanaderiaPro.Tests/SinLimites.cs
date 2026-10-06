using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Planes;
using Moq;

namespace GanaderiaPro.Tests;

// Para las pruebas que no son del plan: un control de límites que siempre deja pasar.
public static class SinLimites
{
    public static IControlLimitesPlan Plan()
    {
        var mock = new Mock<IControlLimitesPlan>();
        mock.Setup(c => c.LugaresLibresAsync(It.IsAny<RecursoPlan>())).ReturnsAsync((int?)null);
        return mock.Object;
    }
}
