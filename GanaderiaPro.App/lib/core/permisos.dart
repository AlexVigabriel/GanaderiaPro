// HU-34: módulos sobre los que el servidor da permisos. Los niveles (Ninguno,
// Lectura, Escritura) llegan del servidor al iniciar sesión: la matriz vive
// en un solo lugar, el backend.
abstract final class Modulos {
  static const ganado = 'Ganado';
  static const pesaje = 'Pesaje';
  static const corrales = 'Corrales';
  static const sanidad = 'Sanidad';
  static const colaboradores = 'Colaboradores';
  static const tablero = 'Tablero';
}

// Módulo de cada ruta protegida (las que no están, como el tablero, las ve
// cualquier usuario con sesión).
const moduloDeRuta = {
  '/ganado': Modulos.ganado,
  '/corrales': Modulos.corrales,
  '/sanidad': Modulos.sanidad,
  '/colaboradores': Modulos.colaboradores,
};
