import 'catalogos.dart';

class Animal {
  Animal({
    required this.id,
    required this.arete,
    required this.sexo,
    required this.raza,
    required this.peso,
    required this.estado,
    required this.fechaRegistro,
    this.nombre,
    this.fechaNacimiento,
    this.pesoNacimiento,
    this.color,
    this.observaciones,
    this.castrado = false,
    this.categoria,
    this.fechaBaja,
    this.observacionBaja,
    this.causaMuerte,
    this.detalleCausaMuerte,
    this.corralId,
    this.corral,
  });

  final String id;
  final String arete;
  final String sexo;
  final String raza;
  final double? peso;
  final String estado;
  final DateTime fechaRegistro;
  final String? nombre;
  final DateTime? fechaNacimiento;
  final double? pesoNacimiento;
  final String? color;
  final String? observaciones;
  final bool castrado;
  // HU-74: la calcula el servidor; null si el animal no tiene fecha de nacimiento.
  final String? categoria;
  // HU-54: datos de la baja; null mientras el animal está Activo.
  final DateTime? fechaBaja;
  final String? observacionBaja;
  final String? causaMuerte;
  final String? detalleCausaMuerte;
  // HU-23: corral donde está (null si no está en ninguno).
  final String? corralId;
  final String? corral;

  // Texto de la causa para mostrar: el detalle escrito si fue "Otra".
  String? get textoCausaMuerte =>
      causaMuerte == 'Otra' ? detalleCausaMuerte : (causaMuerte == null ? null : causasMuerte[causaMuerte]);

  bool get activo => estado == 'Activo';

  factory Animal.fromJson(Map<String, dynamic> json) {
    final nacimiento = json['fechaNacimiento'] as String?;
    final baja = json['fechaBaja'] as String?;
    return Animal(
      id: json['id'] as String,
      arete: json['arete'] as String,
      sexo: json['sexo'] as String,
      raza: json['raza'] as String,
      peso: (json['peso'] as num?)?.toDouble(),
      estado: json['estado'] as String,
      fechaRegistro: DateTime.parse(json['fechaRegistro'] as String),
      nombre: json['nombre'] as String?,
      fechaNacimiento: nacimiento == null ? null : DateTime.parse(nacimiento),
      pesoNacimiento: (json['pesoNacimiento'] as num?)?.toDouble(),
      color: json['color'] as String?,
      observaciones: json['observaciones'] as String?,
      castrado: json['castrado'] as bool? ?? false,
      categoria: json['categoria'] as String?,
      fechaBaja: baja == null ? null : DateTime.parse(baja),
      observacionBaja: json['observacionBaja'] as String?,
      causaMuerte: json['causaMuerte'] as String?,
      detalleCausaMuerte: json['detalleCausaMuerte'] as String?,
      corralId: json['corralId'] as String?,
      corral: json['corral'] as String?,
    );
  }
}

// Datos de un animal tal como se envían al registrarlo o editarlo.
class DatosAnimal {
  const DatosAnimal({
    required this.arete,
    required this.sexo,
    required this.raza,
    this.nombre,
    this.fechaNacimiento,
    this.pesoNacimiento,
    this.peso,
    this.color,
    this.observaciones,
    this.castrado = false,
  });

  final String arete;
  final String sexo;
  final String raza;
  final String? nombre;
  final DateTime? fechaNacimiento;
  final double? pesoNacimiento;
  final double? peso;
  final String? color;
  final String? observaciones;
  final bool castrado;

  Map<String, dynamic> toJson() => {
    'arete': arete,
    'sexo': sexo,
    'raza': raza,
    'peso': peso,
    'nombre': nombre,
    'fechaNacimiento': fechaNacimiento == null ? null : fechaIso(fechaNacimiento!),
    'pesoNacimiento': pesoNacimiento,
    'color': color,
    'observaciones': observaciones,
    // La castración solo aplica a machos.
    'castrado': sexo == 'Macho' && castrado,
  };

  static String fechaIso(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
}

// HU-54: cambio de estado. Para Vendido o Fallecido lleva la fecha; para
// Fallecido, además, la causa.
class DatosEstado {
  const DatosEstado({required this.estado, this.fecha, this.observacion, this.causa, this.detalleCausa});

  final String estado;
  final DateTime? fecha;
  final String? observacion;
  final String? causa;
  final String? detalleCausa;

  Map<String, dynamic> toJson() => {
    'estado': estado,
    'fecha': fecha == null ? null : DatosAnimal.fechaIso(fecha!),
    'observacion': observacion,
    'causa': causa,
    'detalleCausa': detalleCausa,
  };
}

// HU-55: un pesaje del historial.
class Pesaje {
  const Pesaje({required this.id, required this.fecha, required this.peso, this.observacion});

  final String id;
  final DateTime fecha;
  final double peso;
  final String? observacion;

  factory Pesaje.fromJson(Map<String, dynamic> json) => Pesaje(
    id: json['id'] as String,
    fecha: DateTime.parse(json['fecha'] as String),
    peso: (json['peso'] as num).toDouble(),
    observacion: json['observacion'] as String?,
  );
}

class ResumenAnimales {
  const ResumenAnimales({
    required this.activos,
    required this.hembras,
    required this.machos,
    required this.vendidos,
    required this.fallecidos,
  });

  final int activos;
  final int hembras;
  final int machos;
  final int vendidos;
  final int fallecidos;

  factory ResumenAnimales.fromJson(Map<String, dynamic> json) => ResumenAnimales(
    activos: json['activos'] as int,
    hembras: json['hembrasActivas'] as int,
    machos: json['machosActivos'] as int,
    vendidos: json['vendidos'] as int,
    fallecidos: json['fallecidos'] as int,
  );
}

class FilaRechazada {
  const FilaRechazada({required this.fila, required this.motivo});

  final int fila;
  final String motivo;
}

class ResultadoCarga {
  const ResultadoCarga({required this.registrados, required this.rechazados});

  final int registrados;
  final List<FilaRechazada> rechazados;
}
