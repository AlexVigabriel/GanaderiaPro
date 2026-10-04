import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/formato.dart';
import 'package:ganaderia_pro_app/features/ganado/baja_animal_dialog.dart';

void main() {
  final hoy = DateTime.now();
  final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);

  group('Fecha de baja (HU-54)', () {
    test('es obligatoria', () => expect(validarFechaBaja(null, null), 'La fecha es obligatoria'));
    test('acepta hoy', () => expect(validarFechaBaja(soloHoy, null), isNull));
    test('rechaza una fecha futura (RN-14)', () {
      expect(validarFechaBaja(soloHoy.add(const Duration(days: 1)), null), 'La fecha no puede ser futura');
    });
    test('rechaza una fecha anterior al nacimiento', () {
      expect(validarFechaBaja(DateTime(2024, 5, 9), DateTime(2024, 5, 10)), 'No puede ser anterior al nacimiento');
    });
  });

  group('Datos de la baja', () {
    test('fallecido pide causa y, si es "Otra", el detalle escrito', () {
      final datos = DatosBajaFormulario(fecha: soloHoy);
      expect(datos.validar('Fallecido', null), isFalse);
      expect(datos.errores['causa'], 'Elegí la causa de muerte');

      datos.causa = 'Otra';
      expect(datos.validar('Fallecido', null), isFalse);
      expect(datos.errores['detalle'], 'Escribí cuál fue la causa');

      datos.detalle.text = 'Mordedura de víbora';
      expect(datos.validar('Fallecido', null), isTrue);
      expect(datos.aDatos('Fallecido').detalleCausa, 'Mordedura de víbora');
    });

    test('vendido pide la fecha de venta y no envía causa', () {
      final datos = DatosBajaFormulario(causa: 'Accidente');
      expect(datos.validar('Vendido', null), isFalse);
      expect(datos.errores['fecha'], 'La fecha de venta es obligatoria');

      datos.fecha = soloHoy;
      expect(datos.validar('Vendido', null), isTrue);
      expect(datos.aDatos('Vendido').causa, isNull);
    });
  });

  test('Muestra el detalle escrito cuando la causa es "Otra"', () {
    final animal = Animal.fromJson({
      'id': '1',
      'arete': 'AR-001',
      'sexo': 'Hembra',
      'raza': 'Nelore',
      'peso': null,
      'estado': 'Fallecido',
      'fechaRegistro': '2026-10-02T12:00:00Z',
      'fechaBaja': '2026-10-03',
      'causaMuerte': 'Otra',
      'detalleCausaMuerte': 'Mordedura de víbora',
    });

    expect(animal.activo, isFalse);
    expect(animal.textoCausaMuerte, 'Mordedura de víbora');
  });

  test('La edad al morir se calcula hasta la fecha de defunción', () {
    expect(describirEdad(DateTime(2026, 9, 27), hasta: DateTime(2026, 10, 3)), '6 días');
    expect(describirEdad(DateTime(2024, 1, 1), hasta: DateTime(2026, 2, 1)), '2 años');
  });

  testWidgets('La calavera abre "Marcar como fallecido" sin opción de venta', (tester) async {
    final animal = Animal(
      id: '1',
      arete: 'AR-001',
      sexo: 'Macho',
      raza: 'Charolais',
      peso: null,
      estado: 'Activo',
      fechaRegistro: DateTime(2026),
      nombre: 'Rayo',
      fechaNacimiento: soloHoy.subtract(const Duration(days: 6)),
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

    expect(find.text('Marcar como fallecido'), findsNWidgets(2));
    expect(find.text('Rayo'), findsOneWidget);
    expect(find.text('6 días'), findsOneWidget);
    expect(find.text('Venta'), findsNothing);

    // "Otra" muestra el campo para escribir la causa.
    expect(find.text('¿Cuál fue la causa? *'), findsNothing);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otra').last);
    await tester.pumpAndSettle();
    expect(find.text('¿Cuál fue la causa? *'), findsOneWidget);
  });
}
