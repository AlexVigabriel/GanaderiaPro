// HU-36.1 y HU-38: respuesta del asistente de consultas.
class RespuestaAsistente {
  const RespuestaAsistente({
    required this.respuesta,
    required this.reconocida,
    required this.sinDatos,
    this.responsable,
    this.ejemplos = const [],
  });

  final String respuesta;
  // false: no entendió la pregunta y trae ejemplos de las que sí entiende.
  final bool reconocida;
  // true: entendió, pero el dato no está registrado (avisó al responsable).
  final bool sinDatos;
  final String? responsable;
  final List<String> ejemplos;

  factory RespuestaAsistente.fromJson(Map<String, dynamic> json) => RespuestaAsistente(
    respuesta: json['respuesta'] as String,
    reconocida: json['reconocida'] as bool,
    sinDatos: json['sinDatos'] as bool,
    responsable: json['responsable'] as String?,
    ejemplos: (json['ejemplos'] as List<dynamic>? ?? const []).cast<String>(),
  );
}
