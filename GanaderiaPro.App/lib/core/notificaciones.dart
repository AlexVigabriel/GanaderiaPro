import 'package:flutter/foundation.dart';

// HU-40: cantidad de notificaciones sin leer. La campana la consulta y el
// centro de notificaciones (HU-41) la actualiza al marcar leídas.
final notificacionesNoLeidas = ValueNotifier<int>(0);

// HU-41: alerta para el usuario actual.
class Notificacion {
  const Notificacion({
    required this.id,
    required this.tipo,
    required this.mensaje,
    required this.referenciaTipo,
    required this.referenciaId,
    required this.leida,
    required this.fecha,
  });

  final String id;
  // VacunaPendiente, CorralLleno o PartoProximo.
  final String tipo;
  final String mensaje;
  // Animal o Corral: adónde lleva al abrirla.
  final String referenciaTipo;
  final String referenciaId;
  final bool leida;
  final DateTime fecha;

  factory Notificacion.fromJson(Map<String, dynamic> json) => Notificacion(
    id: json['id'] as String,
    tipo: json['tipo'] as String,
    mensaje: json['mensaje'] as String,
    referenciaTipo: json['referenciaTipo'] as String,
    referenciaId: json['referenciaId'] as String,
    leida: json['leida'] as bool,
    fecha: DateTime.parse(json['fecha'] as String).toLocal(),
  );

  Notificacion marcadaLeida() => Notificacion(
    id: id,
    tipo: tipo,
    mensaje: mensaje,
    referenciaTipo: referenciaTipo,
    referenciaId: referenciaId,
    leida: true,
    fecha: fecha,
  );
}
