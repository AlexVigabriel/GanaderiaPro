import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/features/sanidad/registro_vacunacion_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _animal(String id, String arete) => {
  'id': id,
  'arete': arete,
  'sexo': 'Hembra',
  'raza': 'Nelore',
  'peso': null,
  'estado': 'Activo',
  'fechaRegistro': '2026-10-01T12:00:00Z',
  'fechaNacimiento': '2024-01-10',
  'categoria': 'Vaquillona',
};

void main() {
  group('Reglas de la vacunación (HU-26)', () {
    test('la dosis es obligatoria', () => expect(validarDosis(' '), 'La dosis es obligatoria'));
    test('la próxima dosis no puede ser anterior a la aplicación', () {
      expect(validarProximaDosis(DateTime(2026, 10, 3), DateTime(2026, 10, 4)), 'No puede ser anterior a la aplicación');
      expect(validarProximaDosis(DateTime(2026, 10, 4), DateTime(2026, 10, 4)), isNull);
      expect(validarProximaDosis(null, DateTime(2026, 10, 4)), isNull);
    });
  });

  testWidgets('Se vacuna a todos los animales activos en un solo registro', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? enviado;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => abrirRegistroVacunacion(context), child: const Text('abrir')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // Sin animales no deja guardar.
      await tester.tap(find.text('Registrar vacunación').last);
      await tester.pumpAndSettle();
      expect(find.text('Elegí al menos un animal'), findsOneWidget);
      expect(find.text('Elegí la vacuna'), findsOneWidget);

      await tester.tap(find.text('Elegir animales'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos los animales activos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo (2)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fiebre aftosa').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Ej. 5 ml'), '5 ml');

      await tester.tap(find.text('Vacunar 2 animales'));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.url.path.endsWith('/vacunas')) {
        return http.Response(jsonEncode([{'id': 'v1', 'nombre': 'Fiebre aftosa'}]), 200);
      }
      if (request.url.path.endsWith('/animales')) {
        return http.Response(jsonEncode([_animal('a1', 'AR-001'), _animal('a2', 'AR-002')]), 200);
      }
      enviado = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode([{}, {}]), 200);
    }));

    expect(enviado, isNotNull);
    expect(enviado!['animalIds'], ['a1', 'a2']);
    expect(enviado!['vacunaId'], 'v1');
    expect(enviado!['dosis'], '5 ml');
    expect(find.text('Vacunar 2 animales'), findsNothing);
  });
}
