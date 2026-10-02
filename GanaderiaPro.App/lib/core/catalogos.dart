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

// HU-74: categorías que calcula el servidor, con su descripción para el filtro.
const categoriasAnimal = {
  'Ternero': 'Macho de menos de 8 meses',
  'Ternera': 'Hembra de menos de 8 meses',
  'Torito': 'Macho de 8 a 24 meses',
  'Vaquillona': 'Hembra de 8 a 24 meses',
  'Novillo': 'Macho castrado de 8 meses o más',
  'Toro': 'Macho de 24 meses o más',
  'Vaca': 'Hembra de 24 meses o más',
};

// Si un animal ya tiene una raza o color que no está en la lista (por
// ejemplo, cargado antes de que existiera), se suma para poder mostrarlo.
List<String> opcionesCon(List<String> base, String? actual) =>
    actual == null || actual.isEmpty || base.contains(actual) ? base : [...base, actual];
