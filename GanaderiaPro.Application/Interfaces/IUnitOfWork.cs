namespace GanaderiaPro.Application.Interfaces;

public interface IUnitOfWork
{
    Task GuardarCambiosAsync();
}
