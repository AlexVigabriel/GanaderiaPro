// HU-22: un evento de la línea de tiempo del animal.
class EventoHistorial {
  const EventoHistorial({
    required this.fecha,
    required this.tipo,
    this.categoria = '',
    required this.descripcion,
    this.usuario,
  });

  final DateTime fecha;
  // Vacunacion, Tratamiento, SeguimientoTratamiento, FinTratamiento, Pesaje,
  // Servicio, DiagnosticoPrenez, Parto, Aborto, MovimientoCorral, Baja o Reactivacion.
  final String tipo;
  // RC-11: Sanidad, Reproduccion, Pesajes, Corrales o Estado.
  final String categoria;
  final String descripcion;
  // Quién lo registró (vacío en registros anteriores).
  final String? usuario;

  factory EventoHistorial.fromJson(Map<String, dynamic> json) => EventoHistorial(
    fecha: DateTime.parse(json['fecha'] as String),
    tipo: json['tipo'] as String,
    categoria: (json['categoria'] as String?) ?? '',
    descripcion: json['descripcion'] as String,
    usuario: json['usuario'] as String?,
  );
}

const _nombresDeTipo = {
  'Vacunacion': 'Vacunación',
  'Tratamiento': 'Tratamiento',
  'SeguimientoTratamiento': 'Seguimiento del tratamiento',
  'FinTratamiento': 'Fin del tratamiento',
  'Pesaje': 'Pesaje',
  'Servicio': 'Servicio',
  'DiagnosticoPrenez': 'Diagnóstico de preñez',
  'Parto': 'Parto',
  'Aborto': 'Aborto',
  'MovimientoCorral': 'Movimiento de corral',
  'Baja': 'Baja',
  'Reactivacion': 'Reactivación',
};

String nombreDeTipoDeEvento(String tipo) => _nombresDeTipo[tipo] ?? tipo;

// RC-11: filtros del historial (clave del servidor → texto del botón).
const categoriasDeHistorial = {
  'Sanidad': 'Sanidad',
  'Reproduccion': 'Reproducción',
  'Pesajes': 'Pesajes',
  'Corrales': 'Corrales',
  'Estado': 'Estado',
};

// null = todos.
List<EventoHistorial> filtrarHistorial(List<EventoHistorial> eventos, String? categoria) =>
    categoria == null ? eventos : eventos.where((e) => e.categoria == categoria).toList();
