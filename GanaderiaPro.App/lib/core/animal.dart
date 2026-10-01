class Animal {
  Animal({
    required this.id,
    required this.arete,
    required this.sexo,
    required this.raza,
    required this.peso,
    required this.estado,
    required this.fechaRegistro,
  });

  final String id;
  final String arete;
  final String sexo;
  final String raza;
  final double? peso;
  final String estado;
  final DateTime fechaRegistro;

  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      id: json['id'] as String,
      arete: json['arete'] as String,
      sexo: json['sexo'] as String,
      raza: json['raza'] as String,
      peso: (json['peso'] as num?)?.toDouble(),
      estado: json['estado'] as String,
      fechaRegistro: DateTime.parse(json['fechaRegistro'] as String),
    );
  }
}
