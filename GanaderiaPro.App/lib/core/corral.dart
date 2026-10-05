// HU-23 / HU-24: un corral con su ocupación (sin contar bajas).
class Corral {
  const Corral({
    required this.id,
    required this.nombre,
    required this.capacidad,
    required this.activo,
    required this.animalesActivos,
    required this.porcentajeOcupacion,
  });

  final String id;
  final String nombre;
  final int capacidad;
  final bool activo;
  final int animalesActivos;
  final int porcentajeOcupacion;

  int get lugaresLibres => capacidad - animalesActivos;

  factory Corral.fromJson(Map<String, dynamic> json) => Corral(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    capacidad: json['capacidad'] as int,
    activo: json['activo'] as bool,
    animalesActivos: json['animalesActivos'] as int,
    porcentajeOcupacion: json['porcentajeOcupacion'] as int,
  );
}

// HU-24: totales de los corrales activos para las tarjetas de arriba.
class ResumenCorrales {
  const ResumenCorrales({required this.corrales, required this.animales, required this.ocupacionPromedio});

  final int corrales;
  final int animales;
  final int ocupacionPromedio;

  // La ocupación promedio pondera por capacidad: animales / lugares totales.
  factory ResumenCorrales.de(List<Corral> todos) {
    final activos = todos.where((c) => c.activo).toList();
    final animales = activos.fold(0, (suma, c) => suma + c.animalesActivos);
    final lugares = activos.fold(0, (suma, c) => suma + c.capacidad);
    return ResumenCorrales(
      corrales: activos.length,
      animales: animales,
      ocupacionPromedio: lugares == 0 ? 0 : (animales * 100 / lugares).round(),
    );
  }
}
