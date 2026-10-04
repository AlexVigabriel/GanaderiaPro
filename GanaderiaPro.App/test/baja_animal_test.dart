import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/features/ganado/baja_animal_dialog.dart';

void main() {
  final hoy = DateTime.now();
  final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);

  group('Fecha de baja (HU-54)', () {
    test('es obligatoria', () => expect(validarFechaBaja(null, null), 'La fecha de baja es obligatoria'));
    test('acepta hoy', () => expect(validarFechaBaja(soloHoy, null), isNull));
    test('rechaza una fecha futura (RN-14)', () {
      expect(validarFechaBaja(soloHoy.add(const Duration(days: 1)), null), 'La fecha de baja no puede ser futura');
    });
    test('rechaza una fecha anterior al nacimiento', () {
      final nacimiento = DateTime(2024, 5, 10);
      expect(validarFechaBaja(DateTime(2024, 5, 9), nacimiento), 'No puede ser anterior al nacimiento');
    });
  });

  test('Lee los datos de la baja que manda el servidor', () {
    final animal = Animal.fromJson({
      'id': '1',
      'arete': 'AR-001',
      'sexo': 'Hembra',
      'raza': 'Nelore',
      'peso': null,
      'estado': 'Vendido',
      'fechaRegistro': '2026-10-02T12:00:00Z',
      'fechaBaja': '2026-10-03',
      'observacionBaja': 'Feria',
    });

    expect(animal.activo, isFalse);
    expect(animal.fechaBaja, DateTime(2026, 10, 3));
    expect(animal.observacionBaja, 'Feria');
  });

  testWidgets('El formulario de baja ofrece venta o fallecimiento', (tester) async {
    final animal = Animal(
      id: '1',
      arete: 'AR-001',
      sexo: 'Hembra',
      raza: 'Nelore',
      peso: null,
      estado: 'Activo',
      fechaRegistro: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => abrirRegistroBaja(context, animal), child: const Text('abrir')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Registrar baja de AR-001'), findsOneWidget);
    expect(find.text('Venta'), findsOneWidget);
    expect(find.text('Fallecimiento'), findsOneWidget);
    expect(find.text('Registrar baja'), findsOneWidget);
  });
}
