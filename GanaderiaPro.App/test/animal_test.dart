import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/animal.dart';

void main() {
  test('Lee la categoría y la castración que manda el servidor', () {
    final animal = Animal.fromJson({
      'id': '1',
      'arete': 'AR-001',
      'sexo': 'Macho',
      'raza': 'Nelore',
      'peso': null,
      'estado': 'Activo',
      'fechaRegistro': '2026-10-02T12:00:00Z',
      'fechaNacimiento': '2025-06-01',
      'castrado': true,
      'categoria': 'Novillo',
    });

    expect(animal.castrado, isTrue);
    expect(animal.categoria, 'Novillo');
  });

  test('Una hembra nunca se envía como castrada', () {
    const datos = DatosAnimal(arete: 'AR-002', sexo: 'Hembra', raza: 'Gyr', castrado: true);

    expect(datos.toJson()['castrado'], isFalse);
  });
}
