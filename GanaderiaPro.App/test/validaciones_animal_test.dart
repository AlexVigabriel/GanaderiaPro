import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/validaciones_animal.dart';

void main() {
  final hoy = DateTime.now();

  group('Identificación', () {
    test('es obligatoria', () => expect(validarArete('  '), 'La identificación es obligatoria'));
    test('acepta letras, números y guiones', () => expect(validarArete('ar-001'), isNull));
    test('rechaza espacios y otros signos', () {
      expect(validarArete('AR 001'), 'Solo letras, números y guiones');
      expect(validarArete('AR_001'), 'Solo letras, números y guiones');
    });
    test('se normaliza en mayúsculas', () => expect(normalizarIdentificacion(' ar-7 '), 'AR-7'));
  });

  group('Fecha de nacimiento', () {
    test('es obligatoria', () => expect(validarFechaNacimiento(null), 'La fecha de nacimiento es obligatoria'));
    test('acepta hoy', () => expect(validarFechaNacimiento(DateTime(hoy.year, hoy.month, hoy.day)), isNull));
    test('rechaza una fecha futura (RN-14)', () {
      expect(validarFechaNacimiento(hoy.add(const Duration(days: 1))), 'La fecha de nacimiento no puede ser futura');
    });
    test('rechaza más de 20 años (RC-02)', () {
      expect(validarFechaNacimiento(DateTime(hoy.year - 21, hoy.month, hoy.day)), 'No puede tener más de 20 años');
    });
    test('avisa, sin bloquear, desde los 15 años (RC-02)', () {
      final hace17 = DateTime(hoy.year - 17, hoy.month, hoy.day);
      expect(validarFechaNacimiento(hace17), isNull);
      expect(avisoEdad(hace17), contains('edad poco común'));
      expect(avisoEdad(DateTime(hoy.year - 10, hoy.month, hoy.day)), isNull);
    });
  });

  group('Pesos', () {
    test('el peso al nacer va de 15 a 60 kg (RC-01)', () {
      expect(validarPesoNacimiento('14,9'), 'Peso al nacer: de 15 a 60 kg (el peso actual va aparte)');
      expect(validarPesoNacimiento('15'), isNull);
      expect(validarPesoNacimiento('60'), isNull);
      expect(validarPesoNacimiento('60,5'), 'Peso al nacer: de 15 a 60 kg (el peso actual va aparte)');
      expect(validarPesoNacimiento('80'), 'Peso al nacer: de 15 a 60 kg (el peso actual va aparte)');
    });
    test('el peso actual va de 15 a 1500 kg sin fecha de nacimiento', () {
      expect(validarPeso('14'), 'Debe estar entre 15 y 1500 kg');
      expect(validarPeso('1500'), isNull);
      expect(validarPeso('1501'), 'Debe estar entre 15 y 1500 kg');
    });
    test('el peso actual tiene que ser posible para la edad (RC-03)', () {
      final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
      final hace10Dias = hoySinHora.subtract(const Duration(days: 10));
      expect(validarPeso('80', nacimiento: hace10Dias), isNull);
      expect(validarPeso('300', nacimiento: hace10Dias), 'Para su edad, entre 15 y 80 kg');
      expect(validarPeso('420', nacimiento: hoySinHora.subtract(const Duration(days: 180))), isNull);
      expect(validarPeso('1500', nacimiento: DateTime(hoy.year - 5, hoy.month, hoy.day)), isNull);
    });
    test('las observaciones tienen que describir algo (RC-07)', () {
      for (final valida in [
        'Animal nacido completamente sano',
        'Requiere chequeo médico en cuatro días',
        'Peso registrado: 40 kg',
        '',
      ]) {
        expect(validarObservacion(valida), isNull, reason: valida);
      }
      for (final invalida in ['40', '60', '40,5', '--', '4 x']) {
        expect(validarObservacion(invalida), 'Debe describir algo, no solo un número', reason: invalida);
      }
      expect(validarObservacion('Animal tranquilo', 10), 'Hasta 10 caracteres');
    });
    test('los pesos son opcionales pero deben ser números', () {
      expect(validarPeso(''), isNull);
      expect(validarPesoNacimiento('abc'), 'Ingresá un número');
    });
  });
}
