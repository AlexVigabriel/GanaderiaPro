using GanaderiaPro.Application.DTOs;

namespace GanaderiaPro.Application.Interfaces;

// HU-43 y HU-44: leer y escribir la planilla de ganado. La implementación
// (ClosedXML) vive en Infraestructura; la aplicación no depende de la librería.
public interface IPlanillaExcel
{
    byte[] GenerarPlantilla();
    byte[] Exportar(IReadOnlyList<AnimalResponse> animales);
    LecturaPlanilla Leer(Stream archivo);
}
