// HU-56: servicio de una hembra y su parto (RN-10). RC-10: diagnóstico de
// preñez (Confirmada o Vacia) y aborto; «Vacía» y el aborto la cierran.
class Prenez {
  const Prenez({
    required this.id,
    required this.fechaServicio,
    required this.fechaProbableParto,
    this.fechaParto,
    required this.abierta,
    this.observacion,
    this.estado = 'Abierta',
    this.diagnostico,
    this.fechaDiagnostico,
    this.fechaAborto,
  });

  final String id;
  final DateTime fechaServicio;
  final DateTime fechaProbableParto;
  final DateTime? fechaParto;
  final bool abierta;
  final String? observacion;
  // Abierta, Parto, Vacia o Aborto.
  final String estado;
  final String? diagnostico;
  final DateTime? fechaDiagnostico;
  final DateTime? fechaAborto;

  // RC-10: los mismos plazos que el servidor, contados desde el servicio.
  static const diasMinimosDiagnostico = 30;
  static const diasMinimosAborto = 42;
  static const diasMinimosParto = 260;
  static const esperaTrasParto = 40;
  static const esperaTrasAborto = 21;

  bool get confirmada => diagnostico == 'Confirmada';

  DateTime _mas(DateTime f, int dias) => DateTime(f.year, f.month, f.day + dias);
  DateTime _laMasTardia(DateTime a, DateTime? b) => b != null && b.isAfter(a) ? b : a;

  DateTime get diagnosticoDesde => _mas(fechaServicio, diasMinimosDiagnostico);
  DateTime get abortoDesde => _laMasTardia(_mas(fechaServicio, diasMinimosAborto), fechaDiagnostico);
  // El día 260 ya es parto.
  DateTime get abortoHasta => _mas(fechaServicio, diasMinimosParto - 1);
  DateTime get partoDesde => _laMasTardia(_mas(fechaServicio, diasMinimosParto), fechaDiagnostico);

  // Desde cuándo se acepta un servicio nuevo, si esta preñez está cerrada.
  DateTime? get servicioPosibleDesde => switch (estado) {
    'Parto' => _mas(fechaParto!, esperaTrasParto),
    'Aborto' => _mas(fechaAborto!, esperaTrasAborto),
    'Vacia' => fechaDiagnostico,
    _ => null,
  };

  // Fecha en que se cerró, para no aceptar un servicio nuevo anterior.
  DateTime? get fechaCierre => switch (estado) {
    'Parto' => fechaParto,
    'Aborto' => fechaAborto,
    'Vacia' => fechaDiagnostico,
    _ => null,
  };

  factory Prenez.fromJson(Map<String, dynamic> json) {
    DateTime? fecha(String clave) {
      final valor = json[clave] as String?;
      return valor == null ? null : DateTime.parse(valor);
    }

    return Prenez(
      id: json['id'] as String,
      fechaServicio: DateTime.parse(json['fechaServicio'] as String),
      fechaProbableParto: DateTime.parse(json['fechaProbableParto'] as String),
      fechaParto: fecha('fechaParto'),
      abierta: json['abierta'] as bool,
      observacion: json['observacion'] as String?,
      estado: (json['estado'] as String?) ?? 'Abierta',
      diagnostico: json['diagnostico'] as String?,
      fechaDiagnostico: fecha('fechaDiagnostico'),
      fechaAborto: fecha('fechaAborto'),
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
