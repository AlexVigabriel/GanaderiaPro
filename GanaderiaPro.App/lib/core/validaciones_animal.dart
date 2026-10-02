import 'package:flutter/services.dart';

// Las mismas reglas que valida el servidor (AnimalService). Se repiten acá
// solo para avisar antes de enviar; el servidor siempre vuelve a validar.
const double pesoMaximoKg = 1500;
const double pesoNacimientoMinimoKg = 10;
const double pesoNacimientoMaximoKg = 80;
const int antiguedadMaximaAnios = 25;

final _formatoIdentificacion = RegExp(r'^[A-Z0-9-]+$');

// La identificación (arete o caravana) se escribe en mayúsculas y solo con
// letras, números y guiones, para que no se repita con otra forma (RN-01).
final List<TextInputFormatter> formatoIdentificacion = [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
  LengthLimitingTextInputFormatter(50),
  _MayusculasFormatter(),
];

class _MayusculasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) =>
      nuevo.copyWith(text: nuevo.text.toUpperCase());
}

String normalizarIdentificacion(String texto) => texto.trim().toUpperCase();

String? validarArete(String? valor) {
  final texto = normalizarIdentificacion(valor ?? '');
  if (texto.isEmpty) return 'La identificación es obligatoria';
  if (texto.length > 50) return 'Hasta 50 caracteres';
  if (!_formatoIdentificacion.hasMatch(texto)) return 'Solo letras, números y guiones';
  return null;
}

String? validarRaza(String? valor) =>
    (valor == null || valor.trim().isEmpty) ? 'La raza es obligatoria' : null;

String? validarSexo(String? valor) => (valor == null || valor.isEmpty) ? 'Elegí el sexo' : null;

DateTime _hoy() {
  final ahora = DateTime.now();
  return DateTime(ahora.year, ahora.month, ahora.day);
}

// Fecha más antigua que se acepta como nacimiento.
DateTime fechaNacimientoMinima() {
  final hoy = _hoy();
  return DateTime(hoy.year - antiguedadMaximaAnios, hoy.month, hoy.day);
}

// Obligatoria (puede ser aproximada); RN-14: no se registran fechas futuras.
String? validarFechaNacimiento(DateTime? fecha) {
  if (fecha == null) return 'La fecha de nacimiento es obligatoria';
  if (fecha.isAfter(_hoy())) return 'La fecha de nacimiento no puede ser futura';
  if (fecha.isBefore(fechaNacimientoMinima())) return 'No puede tener más de $antiguedadMaximaAnios años';
  return null;
}

String? validarPesoNacimiento(String? valor) =>
    _validarRango(valor, (p) => p >= pesoNacimientoMinimoKg && p <= pesoNacimientoMaximoKg, 'Debe estar entre 10 y 80 kg');

String? validarPeso(String? valor) =>
    _validarRango(valor, (p) => p > 0 && p <= pesoMaximoKg, 'Debe ser mayor que 0 y de hasta 1500 kg');

String? _validarRango(String? valor, bool Function(double) enRango, String mensaje) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return null;
  final peso = leerPeso(texto);
  if (peso == null) return 'Ingresá un número';
  return enRango(peso) ? null : mensaje;
}

String? validarLargo(String? valor, int maximo) =>
    (valor != null && valor.trim().length > maximo) ? 'Hasta $maximo caracteres' : null;

double? leerPeso(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));
