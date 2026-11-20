import 'package:flutter/services.dart';

// Las mismas reglas que valida el servidor (LimitesGanado). Se repiten acá
// solo para avisar antes de enviar; el servidor siempre vuelve a validar.
// Fundamento y fuentes: GanaderiaPro_Requisitos_Correccion_Sprint3 (RC-01 a RC-03).
const double pesoMaximoKg = 1500;
// RC-01: rango de un ternero recién nacido (Jersey ~19 kg a Holstein ~52 kg).
const double pesoNacimientoMinimoKg = 15;
const double pesoNacimientoMaximoKg = 60;
// RC-03: el peso actual no baja del mínimo al nacer y sube como máximo 2 kg por día.
const double pesoMinimoKg = pesoNacimientoMinimoKg;
const double gananciaMaximaDiariaKg = 2;
// RC-02: la vida de un bovino llega a unos 20 años; más de 15 es poco común.
const int antiguedadMaximaAnios = 20;
const int edadAvisoAnios = 15;

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

// Fecha de hoy sin la hora. DateTime.now() trae la hora, y "hoy a las 18:44"
// es posterior a "hoy a las 00:00": compararlas así daba "fecha futura".
DateTime fechaDeHoy() {
  final ahora = DateTime.now();
  return DateTime(ahora.year, ahora.month, ahora.day);
}

DateTime _hoy() => fechaDeHoy();

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

// RC-02: se acepta, pero se pide revisar la fecha.
String? avisoEdad(DateTime? nacimiento) {
  if (nacimiento == null) return null;
  final hoy = _hoy();
  final limite = DateTime(hoy.year - edadAvisoAnios, hoy.month, hoy.day);
  return nacimiento.isBefore(limite) ? 'Más de $edadAvisoAnios años: edad poco común, revisá la fecha' : null;
}

String? validarPesoNacimiento(String? valor) => _validarRango(
  valor,
  (p) => p >= pesoNacimientoMinimoKg && p <= pesoNacimientoMaximoKg,
  'Peso al nacer: de ${_kg(pesoNacimientoMinimoKg)} a ${_kg(pesoNacimientoMaximoKg)} kg (el peso actual va aparte)',
);

// RC-03: peso más alto posible para un animal nacido en «nacimiento» a la
// fecha «fecha» (por defecto, hoy). Sin nacimiento, solo el tope general.
double pesoMaximoParaEdad(DateTime? nacimiento, [DateTime? fecha]) {
  if (nacimiento == null) return pesoMaximoKg;
  final dia = fecha ?? _hoy();
  final dias = DateTime.utc(dia.year, dia.month, dia.day)
      .difference(DateTime.utc(nacimiento.year, nacimiento.month, nacimiento.day))
      .inDays;
  final maximo = pesoNacimientoMaximoKg + gananciaMaximaDiariaKg * (dias < 0 ? 0 : dias);
  return maximo < pesoMaximoKg ? maximo : pesoMaximoKg;
}

String? validarPeso(String? valor, {DateTime? nacimiento, DateTime? fecha}) {
  final maximo = pesoMaximoParaEdad(nacimiento, fecha);
  return _validarRango(
    valor,
    (p) => p >= pesoMinimoKg && p <= maximo,
    maximo < pesoMaximoKg
        ? 'Para su edad, entre ${_kg(pesoMinimoKg)} y ${_kg(maximo)} kg'
        : 'Debe estar entre ${_kg(pesoMinimoKg)} y ${_kg(pesoMaximoKg)} kg',
  );
}

String _kg(double kg) => kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString().replaceAll('.', ',');

String? _validarRango(String? valor, bool Function(double) enRango, String mensaje) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return null;
  final peso = leerPeso(texto);
  if (peso == null) return 'Ingresá un número';
  return enRango(peso) ? null : mensaje;
}

String? validarLargo(String? valor, int maximo) =>
    (valor != null && valor.trim().length > maximo) ? 'Hasta $maximo caracteres' : null;

// RC-07: una observación tiene que describir algo (al menos una palabra de
// tres letras). «40» solo no dice nada; «Peso registrado: 40 kg» sí. Vacío
// es válido porque el campo es opcional. Misma regla que TextoDescriptivo.
final _palabraDeTresLetras = RegExp(r'\p{L}{3,}', unicode: true);

String? validarObservacion(String? valor, [int maximo = 500]) {
  final texto = valor?.trim() ?? '';
  if (texto.length > maximo) return 'Hasta $maximo caracteres';
  if (texto.isNotEmpty && !_palabraDeTresLetras.hasMatch(texto)) return 'Debe describir algo, no solo un número';
  return null;
}

double? leerPeso(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));
