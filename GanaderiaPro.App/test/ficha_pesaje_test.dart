import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/features/ganado/ficha_animal_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Simula el servidor: guarda los pesajes en memoria y el peso actual del animal.
class _ServidorFalso {
  final pesajes = <Map<String, dynamic>>[];
  double peso = 300;

  Map<String, dynamic> get animal => {
    'id': 'a1',
    'arete': 'AR-002',
    'sexo': 'Hembra',
    'raza': 'Nelore',
    'peso': peso,
    'estado': 'Activo',
    'fechaRegistro': '2026-10-01T12:00:00Z',
    'fechaNacimiento': '2022-11-02',
  };

  Future<http.Response> responder(http.Request request) async {
    final ruta = request.url.path;
    if (ruta.endsWith('/pesajes') && request.method == 'POST') {
      final cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
      peso = (cuerpo['peso'] as num).toDouble();
      pesajes.insert(0, {'id': 'p${pesajes.length}', 'fecha': cuerpo['fecha'], 'peso': peso, 'observacion': null});
      return http.Response(jsonEncode({'pesaje': pesajes.first, 'pesoActualAnimal': peso}), 200);
    }
    if (ruta.endsWith('/pesajes')) return http.Response(jsonEncode(pesajes), 200);
    if (ruta.contains('/pesajes/')) {
      final id = ruta.split('/').last;
      if (request.method == 'DELETE') {
        pesajes.removeWhere((p) => p['id'] == id);
      } else {
        final cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
        pesajes.firstWhere((p) => p['id'] == id)['peso'] = (cuerpo['peso'] as num).toDouble();
      }
      if (pesajes.isNotEmpty) peso = (pesajes.first['peso'] as num).toDouble();
      return http.Response(jsonEncode({'pesoActualAnimal': peso}), 200);
    }
    return http.Response(jsonEncode(animal), 200);
  }
}

void main() {
  testWidgets('Al guardar un pesaje con la fecha de hoy, la ficha se actualiza sola', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final servidor = _ServidorFalso();

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.claro, home: const FichaAnimalScreen(animalId: 'a1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('300 kg'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Registrar pesaje'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '669');
      // Sin tocar el calendario: la fecha por defecto (hoy) tiene que ser válida.
      await tester.tap(find.text('Guardar pesaje'));
      await tester.pumpAndSettle();

      expect(find.text('La fecha no puede ser futura'), findsNothing);
      expect(find.text('Guardar pesaje'), findsNothing);
      expect(find.text('669 kg'), findsWidgets);
    }, () => MockClient(servidor.responder));
  });

  testWidgets('Un pesaje cargado por error se corrige y se elimina desde la ficha', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final servidor = _ServidorFalso()
      ..pesajes.addAll([
        {'id': 'p2', 'fecha': '2026-10-03', 'peso': 55.0, 'observacion': null},
        {'id': 'p1', 'fecha': '2026-08-31', 'peso': 333.0, 'observacion': null},
      ])
      ..peso = 55;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.claro, home: const FichaAnimalScreen(animalId: 'a1')),
      );
      await tester.pumpAndSettle();

      // Corregir 55 → 355 (cambio brusco respecto de 333: no, es +7 %).
      await tester.tap(find.byTooltip('Editar pesaje').first);
      await tester.pumpAndSettle();
      expect(find.text('Editar pesaje'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '355');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('355 kg'), findsWidgets);

      // Eliminar ese pesaje: el peso actual vuelve al anterior (333).
      await tester.tap(find.byTooltip('Eliminar pesaje').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('355 kg'), findsNothing);
      expect(find.text('333 kg'), findsWidgets);
    }, () => MockClient(servidor.responder));
  });
}
