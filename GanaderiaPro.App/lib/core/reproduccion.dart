// HU-56: servicio de una hembra y su parto (RN-10).
class Prenez {
  const Prenez({
    required this.id,
    required this.fechaServicio,
    required this.fechaProbableParto,
    this.fechaParto,
    required this.abierta,
    this.observacion,
  });

  final String id;
  final DateTime fechaServicio;
  final DateTime fechaProbableParto;
  final DateTime? fechaParto;
  final bool abierta;
  final String? observacion;

  factory Prenez.fromJson(Map<String, dynamic> json) {
    final parto = json['fechaParto'] as String?;
    return Prenez(
      id: json['id'] as String,
      fechaServicio: DateTime.parse(json['fechaServicio'] as String),
      fechaProbableParto: DateTime.parse(json['fechaProbableParto'] as String),
      fechaParto: parto == null ? null : DateTime.parse(parto),
      abierta: json['abierta'] as bool,
      observacion: json['observacion'] as String?,
    );
  }
}

// Texto corto de cuánto falta para el parto probable, respecto de hoy.
String describirParto(DateTime probable, DateTime hoy) {
  final dias = DateTime(probable.year, probable.month, probable.day).difference(hoy).inDays;
  if (dias == 0) return 'parto probable hoy';
  if (dias == 1) return 'falta 1 día';
  if (dias > 1) return 'faltan $dias días';
  if (dias == -1) return 'venció ayer';
  return 'venció hace ${-dias} días';
}
