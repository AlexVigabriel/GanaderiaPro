using GanaderiaPro.Application.Interfaces;

namespace GanaderiaPro.Infrastructure;

// TODO: reemplazar por el RanchoId real del usuario autenticado cuando exista login (JWT) — Choquecallata, HU-07/HU-09.
public class StubCurrentUserContext : ICurrentUserContext
{
    public static readonly Guid RanchoDePruebaId = new("11111111-1111-1111-1111-111111111111");

    public Guid RanchoId => RanchoDePruebaId;
}
