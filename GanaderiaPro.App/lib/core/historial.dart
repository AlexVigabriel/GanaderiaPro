// HU-22: un evento de la línea de tiempo del animal.
class EventoHistorial {
  const EventoHistorial({required this.fecha, required this.tipo, required this.descripcion, this.usuario});

  final DateTime fecha;
  // Vacunacion, Tratamiento, Pesaje, Servicio, Parto o MovimientoCorral.
  final String tipo;
  final String descripcion;
  // Quién lo registró (vacío en registros anteriores).
  final String? usuario;

  factory EventoHistorial.fromJson(Map<String, dynamic> json) => EventoHistorial(
    fecha: DateTime.parse(json['fecha'] as String),
    tipo: json['tipo'] as String,
    descripcion: json['descripcion'] as String,
    usuario: json['usuario'] as String?,
  );
}

const _nombresDeTipo = {
  'Vacunacion': 'Vacunación',
  'Tratamiento': 'Tratamiento',
  'Pesaje': 'Pesaje',
  'Servicio': 'Servicio',
  'Parto': 'Parto',
  'MovimientoCorral': 'Movimiento de corral',
};

String nombreDeTipoDeEvento(String tipo) => _nombresDeTipo[tipo] ?? tipo;
