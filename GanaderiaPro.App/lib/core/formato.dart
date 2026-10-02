String formatearFecha(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

String formatearPeso(double? peso) {
  if (peso == null) return '—';
  final texto = peso == peso.roundToDouble() ? peso.toStringAsFixed(0) : peso.toStringAsFixed(1);
  return '$texto kg';
}

String describirEdad(DateTime nacimiento) {
  final hoy = DateTime.now();
  var meses = (hoy.year - nacimiento.year) * 12 + hoy.month - nacimiento.month;
  if (hoy.day < nacimiento.day) meses--;
  if (meses < 1) return 'menos de 1 mes';
  if (meses < 24) return meses == 1 ? '1 mes' : '$meses meses';
  final anios = meses ~/ 12;
  return '$anios años';
}

String iniciales(String? nombre) {
  final partes = (nombre ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return 'GP';
  if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
  return (partes[0][0] + partes[1][0]).toUpperCase();
}
