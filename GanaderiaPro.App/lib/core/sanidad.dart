// HU-26: datos del módulo Sanidad.
class Vacuna {
  const Vacuna({required this.id, required this.nombre});

  final String id;
  final String nombre;

  factory Vacuna.fromJson(Map<String, dynamic> json) =>
      Vacuna(id: json['id'] as String, nombre: json['nombre'] as String);
}

class Vacunacion {
  const Vacunacion({
    required this.id,
    required this.animalId,
    required this.arete,
    this.nombreAnimal,
    required this.vacunaId,
    required this.vacuna,
    required this.dosis,
    required this.fechaAplicacion,
    this.fechaProximaDosis,
    this.observacion,
    required this.veterinario,
  });

  final String id;
  final String animalId;
  final String arete;
  final String? nombreAnimal;
  final String vacunaId;
  final String vacuna;
  final String dosis;
  final DateTime fechaAplicacion;
  final DateTime? fechaProximaDosis;
  final String? observacion;
  final String veterinario;

  String get animal => nombreAnimal == null ? arete : '$arete · $nombreAnimal';

  factory Vacunacion.fromJson(Map<String, dynamic> json) {
    final proxima = json['fechaProximaDosis'] as String?;
    return Vacunacion(
      id: json['id'] as String,
      animalId: json['animalId'] as String,
      arete: json['arete'] as String,
      nombreAnimal: json['nombreAnimal'] as String?,
      vacunaId: json['vacunaId'] as String,
      vacuna: json['vacuna'] as String,
      dosis: json['dosis'] as String,
      fechaAplicacion: DateTime.parse(json['fechaAplicacion'] as String),
      fechaProximaDosis: proxima == null ? null : DateTime.parse(proxima),
      observacion: json['observacion'] as String?,
      veterinario: json['veterinario'] as String,
    );
  }
}

// Resultado de revisar repetidas antes de vacunar: bloqueos (la misma
// vacuna el mismo día) y avisos para confirmar (programada o reciente).
class AvisoVacunacion {
  const AvisoVacunacion({required this.animalId, required this.motivo});

  final String animalId;
  final String motivo;

  factory AvisoVacunacion.fromJson(Map<String, dynamic> json) =>
      AvisoVacunacion(animalId: json['animalId'] as String, motivo: json['motivo'] as String);
}

class VerificacionVacunacion {
  const VerificacionVacunacion({required this.bloqueos, required this.avisos});

  final List<AvisoVacunacion> bloqueos;
  final List<AvisoVacunacion> avisos;

  bool get vacia => bloqueos.isEmpty && avisos.isEmpty;

  factory VerificacionVacunacion.fromJson(Map<String, dynamic> json) {
    List<AvisoVacunacion> leer(String clave) => (json[clave] as List<dynamic>)
        .map((a) => AvisoVacunacion.fromJson(a as Map<String, dynamic>))
        .toList();
    return VerificacionVacunacion(bloqueos: leer('bloqueos'), avisos: leer('avisos'));
  }
}

// Datos de una vacunación tal como se envían al registrarla o editarla.
class DatosVacunacion {
  const DatosVacunacion({
    required this.vacunaId,
    required this.dosis,
    required this.fechaAplicacion,
    this.fechaProximaDosis,
    this.observacion,
  });

  final String vacunaId;
  final String dosis;
  final DateTime fechaAplicacion;
  final DateTime? fechaProximaDosis;
  final String? observacion;

  Map<String, dynamic> toJson() => {
    'vacunaId': vacunaId,
    'dosis': dosis,
    'fechaAplicacion': _iso(fechaAplicacion),
    'fechaProximaDosis': fechaProximaDosis == null ? null : _iso(fechaProximaDosis!),
    'observacion': observacion,
  };

  static String _iso(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
}
