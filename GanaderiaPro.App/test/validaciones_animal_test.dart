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
    test('rechaza más de 25 años', () {
      expect(validarFechaNacimiento(DateTime(hoy.year - 26, hoy.month, hoy.day)), 'No puede tener más de 25 años');
    });
  });

  group('Pesos', () {
    test('el peso al nacer va de 10 a 80 kg', () {
      expect(validarPesoNacimiento('9'), 'Debe estar entre 10 y 80 kg');
      expect(validarPesoNacimiento('10'), isNull);
      expect(validarPesoNacimiento('80'), isNull);
      expect(validarPesoNacimiento('80,5'), 'Debe estar entre 10 y 80 kg');
    });
    test('el peso actual va de más de 0 a 1500 kg', () {
      expect(validarPeso('0'), 'Debe ser mayor que 0 y de hasta 1500 kg');
      expect(validarPeso('1500'), isNull);
      expect(validarPeso('1501'), 'Debe ser mayor que 0 y de hasta 1500 kg');
    });
    test('los pesos son opcionales pero deben ser números', () {
      expect(validarPeso(''), isNull);
      expect(validarPesoNacimiento('abc'), 'Ingresá un número');
    });
  });
}
