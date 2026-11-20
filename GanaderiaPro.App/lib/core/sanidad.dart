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

// HU-27: indicadores del módulo Sanidad (RN-09).
class ResumenSanidad {
  const ResumenSanidad({required this.vacunados, required this.pendientes, required this.vencidas});

  final int vacunados;
  final int pendientes;
  final int vencidas;

  factory ResumenSanidad.fromJson(Map<String, dynamic> json) => ResumenSanidad(
    vacunados: json['vacunados'] as int,
    pendientes: json['pendientes'] as int,
    vencidas: json['vencidas'] as int,
  );
}

// HU-27: una próxima dosis por aplicar.
class Pendiente {
  const Pendiente({
    required this.animalId,
    required this.arete,
    this.nombreAnimal,
    required this.vacunaId,
    required this.vacuna,
    required this.ultimaAplicacion,
    required this.fechaProximaDosis,
    required this.vencida,
  });

  final String animalId;
  final String arete;
  final String? nombreAnimal;
  final String vacunaId;
  final String vacuna;
  final DateTime ultimaAplicacion;
  final DateTime fechaProximaDosis;
  final bool vencida;

  String get animal => nombreAnimal == null ? arete : '$arete · $nombreAnimal';

  factory Pendiente.fromJson(Map<String, dynamic> json) => Pendiente(
    animalId: json['animalId'] as String,
    arete: json['arete'] as String,
    nombreAnimal: json['nombreAnimal'] as String?,
    vacunaId: json['vacunaId'] as String,
    vacuna: json['vacuna'] as String,
    ultimaAplicacion: DateTime.parse(json['ultimaAplicacion'] as String),
    fechaProximaDosis: DateTime.parse(json['fechaProximaDosis'] as String),
    vencida: json['vencida'] as bool,
  );
}

// Texto corto de cuándo vence una dosis pendiente, respecto de hoy.
String describirVencimiento(DateTime fecha, DateTime hoy) {
  final dias = DateTime(fecha.year, fecha.month, fecha.day).difference(hoy).inDays;
  if (dias == 0) return 'Hoy';
  if (dias == 1) return 'Mañana';
  if (dias > 1) return 'En $dias días';
  if (dias == -1) return 'Vencida ayer';
  return 'Vencida hace ${-dias} días';
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

// RC-08: unidades aceptadas para la dosis (el servidor exige cantidad y unidad).
const unidadesDosis = ['ml', 'mg', 'g', 'cc', 'UI', 'comprimidos'];

// Cantidad de la dosis: un número mayor que cero, con coma o punto decimal.
String? validarCantidadDosis(String texto) {
  final limpio = texto.trim();
  if (limpio.isEmpty) return 'Escribí la cantidad';
  final valor = double.tryParse(limpio.replaceAll(',', '.'));
  if (valor == null || !RegExp(r'^\d+([.,]\d+)?$').hasMatch(limpio)) return 'Solo un número, ej. 5';
  if (valor <= 0) return 'Mayor que cero';
  return null;
}

// «1 comprimidos» se lee mal: con 1 va en singular.
String armarDosis(String cantidad, String unidad) {
  final c = cantidad.trim();
  return unidad == 'comprimidos' && c == '1' ? '1 comprimido' : '$c $unidad';
}

// RC-09: valores tal como los manda el servidor y su texto en pantalla.
const nombresEvolucion = {'Mejora': 'Mejora', 'SinCambios': 'Sin cambios', 'Empeora': 'Empeora'};
const nombresResultado = {'Recuperado': 'Recuperado', 'SinMejoria': 'Sin mejoría', 'Derivado': 'Derivado'};

// RC-09: un día del seguimiento de un tratamiento.
class SeguimientoTratamiento {
  const SeguimientoTratamiento({
    required this.id,
    required this.fecha,
    required this.evolucion,
    this.nota,
    required this.usuario,
  });

  final String id;
  final DateTime fecha;
  // Mejora, SinCambios o Empeora.
  final String evolucion;
  final String? nota;
  final String usuario;

  factory SeguimientoTratamiento.fromJson(Map<String, dynamic> json) => SeguimientoTratamiento(
    id: json['id'] as String,
    fecha: DateTime.parse(json['fecha'] as String),
    evolucion: json['evolucion'] as String,
    nota: json['nota'] as String?,
    usuario: json['usuario'] as String,
  );
}

// HU-57: tratamiento veterinario de un animal. RC-08: diagnóstico.
// RC-09: estado, día actual, seguimientos y resultado.
class Tratamiento {
  const Tratamiento({
    required this.id,
    required this.animalId,
    required this.arete,
    this.nombreAnimal,
    required this.diagnostico,
    required this.medicamento,
    required this.dosis,
    required this.fechaInicio,
    required this.duracionDias,
    required this.fechaFin,
    required this.enCurso,
    required this.estado,
    required this.diaActual,
    this.resultado,
    this.fechaFinalizacion,
    this.observacion,
    required this.veterinario,
    this.seguimientos = const [],
  });

  final String id;
  final String animalId;
  final String arete;
  final String? nombreAnimal;
  final String diagnostico;
  final String medicamento;
  final String dosis;
  final DateTime fechaInicio;
  final int duracionDias;
  final DateTime fechaFin;
  final bool enCurso;
  // EnCurso, Finalizado o SinResultado (pasó el último día sin cargar cómo terminó).
  final String estado;
  final int diaActual;
  final String? resultado;
  final DateTime? fechaFinalizacion;
  final String? observacion;
  final String veterinario;
  final List<SeguimientoTratamiento> seguimientos;

  String get animal => nombreAnimal == null ? arete : '$arete · $nombreAnimal';

  bool get finalizado => resultado != null;

  String get avance => 'Día $diaActual de $duracionDias';

  String get textoEstado => switch (estado) {
    'EnCurso' => 'En curso',
    'Finalizado' => nombresResultado[resultado] ?? 'Finalizado',
    _ => 'Sin resultado',
  };

  // Hasta qué día se puede cargar un seguimiento: el último día o hoy.
  DateTime ultimoDiaSeguimiento(DateTime hoy) => fechaFin.isBefore(hoy) ? fechaFin : hoy;

  factory Tratamiento.fromJson(Map<String, dynamic> json) {
    final finalizacion = json['fechaFinalizacion'] as String?;
    return Tratamiento(
      id: json['id'] as String,
      animalId: json['animalId'] as String,
      arete: json['arete'] as String,
      nombreAnimal: json['nombreAnimal'] as String?,
      diagnostico: json['diagnostico'] as String,
      medicamento: json['medicamento'] as String,
      dosis: json['dosis'] as String,
      fechaInicio: DateTime.parse(json['fechaInicio'] as String),
      duracionDias: json['duracionDias'] as int,
      fechaFin: DateTime.parse(json['fechaFin'] as String),
      enCurso: json['enCurso'] as bool,
      estado: json['estado'] as String,
      diaActual: json['diaActual'] as int,
      resultado: json['resultado'] as String?,
      fechaFinalizacion: finalizacion == null ? null : DateTime.parse(finalizacion),
      observacion: json['observacion'] as String?,
      veterinario: json['veterinario'] as String,
      seguimientos: ((json['seguimientos'] as List<dynamic>?) ?? const [])
          .map((s) => SeguimientoTratamiento.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Datos de un tratamiento tal como se envían al registrarlo.
class DatosTratamiento {
  const DatosTratamiento({
    required this.diagnostico,
    required this.medicamento,
    required this.dosis,
    required this.fechaInicio,
    required this.duracionDias,
    this.observacion,
  });

  final String diagnostico;
  final String medicamento;
  final String dosis;
  final DateTime fechaInicio;
  final int duracionDias;
  final String? observacion;
}
