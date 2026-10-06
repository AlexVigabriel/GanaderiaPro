import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/features/ganado/pesajes_animal.dart';

void main() {
  group('Peso del pesaje (HU-55)', () {
    test('es obligatorio', () => expect(validarPesoPesaje(''), 'El peso es obligatorio'));
    test('va de más de 0 a 1500 kg', () {
      expect(validarPesoPesaje('0'), 'Debe ser mayor que 0 y de hasta 1500 kg');
      expect(validarPesoPesaje('1500'), isNull);
      expect(validarPesoPesaje('1500,5'), 'Debe ser mayor que 0 y de hasta 1500 kg');
      expect(validarPesoPesaje('345,5'), isNull);
    });
  });

  group('Cambio brusco de peso', () {
    final historial = [
      Pesaje(id: '1', fecha: DateTime(2026, 7, 1), peso: 222),
      Pesaje(id: '2', fecha: DateTime(2026, 8, 31), peso: 333),
    ];

    test('compara con el pesaje inmediatamente anterior a la fecha', () {
      expect(pesajeAnterior(historial, DateTime(2026, 10, 4))!.peso, 333);
      expect(pesajeAnterior(historial, DateTime(2026, 8, 1))!.peso, 222);
      expect(pesajeAnterior(historial, DateTime(2026, 6, 1)), isNull);
    });

    test('más de 30 % de cambio pide confirmación', () {
      expect(esCambioBrusco(333, 55), isTrue);
      expect(esCambioBrusco(333, 666), isTrue);
      expect(esCambioBrusco(333, 400), isFalse);
    });
  });

  test('Lee un pesaje que manda el servidor', () {
    final pesaje = Pesaje.fromJson({'id': '1', 'fecha': '2026-10-04', 'peso': 345.5, 'observacion': null});

    expect(pesaje.fecha, DateTime(2026, 10, 4));
    expect(pesaje.peso, 345.5);
  });

  testWidgets('El formulario de pesaje pide el peso', (tester) async {
    final animal = Animal(
      id: '1',
      arete: 'AR-001',
      sexo: 'Macho',
      raza: 'Nelore',
      peso: 300,
      estado: 'Activo',
      fechaRegistro: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => abrirRegistroPesaje(context, animal), child: const Text('abrir')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar pesaje'), findsOneWidget);

    await tester.tap(find.text('Guardar pesaje'));
    await tester.pump();

    expect(find.text('El peso es obligatorio'), findsOneWidget);
  });
}
