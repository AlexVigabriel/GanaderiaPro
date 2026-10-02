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

  factory Animal.fromJson(Map<String, dynamic> json) {
    final nacimiento = json['fechaNacimiento'] as String?;
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

  Map<String, dynamic> toJson() => {
    'arete': arete,
    'sexo': sexo,
    'raza': raza,
    'peso': peso,
    'nombre': nombre,
    'fechaNacimiento': fechaNacimiento == null ? null : _fechaIso(fechaNacimiento!),
    'pesoNacimiento': pesoNacimiento,
    'color': color,
    'observaciones': observaciones,
  };

  static String _fechaIso(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
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
