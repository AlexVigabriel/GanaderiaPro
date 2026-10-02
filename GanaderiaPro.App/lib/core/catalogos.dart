// Opciones fijas de las listas desplegables. La raza se guarda como texto,
// así que agregar una opción acá no requiere cambios en el servidor.
const razasBovinas = [
  'Nelore',
  'Brahman',
  'Gyr',
  'Criollo',
  'Angus',
  'Hereford',
  'Holstein',
  'Pardo Suizo',
  'Simmental',
  'Charolais',
  'Senepol',
  'Mestizo',
];

const coloresPelaje = [
  'Blanco',
  'Negro',
  'Colorado',
  'Bayo',
  'Gris',
  'Hosco',
  'Overo negro',
  'Overo colorado',
  'Pinto',
];

// Si un animal ya tiene una raza o color que no está en la lista (por
// ejemplo, cargado antes de que existiera), se suma para poder mostrarlo.
List<String> opcionesCon(List<String> base, String? actual) =>
    actual == null || actual.isEmpty || base.contains(actual) ? base : [...base, actual];
