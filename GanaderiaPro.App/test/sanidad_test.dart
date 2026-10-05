import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/sanidad.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/features/sanidad/sanidad_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() => SesionActual.instancia.guardar(token: 't', nombreRancho: 'Estancia', nombreUsuario: 'Ana Vega'));
  tearDown(SesionActual.instancia.cerrar);

  Future<void> abrir(WidgetTester tester, MockClient servidor) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const SanidadScreen()));
      await tester.pumpAndSettle();
    }, () => servidor);
  }

  test('Describe cuándo vence una dosis', () {
    final hoy = DateTime(2026, 10, 4);
    expect(describirVencimiento(DateTime(2026, 10, 4), hoy), 'Hoy');
    expect(describirVencimiento(DateTime(2026, 10, 9), hoy), 'En 5 días');
    expect(describirVencimiento(DateTime(2026, 10, 3), hoy), 'Vencida ayer');
    expect(describirVencimiento(DateTime(2026, 9, 24), hoy), 'Vencida hace 10 días');
  });

  testWidgets('Sin vacunaciones, los indicadores muestran 0 sin errores', (tester) async {
    await abrir(
      tester,
      MockClient((request) async {
        if (request.url.path.endsWith('/resumen')) {
          return http.Response(jsonEncode({'vacunados': 0, 'pendientes': 0, 'vencidas': 0}), 200);
        }
        return http.Response('[]', 200);
      }),
    );

    expect(find.text('VACUNADOS'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('No hay dosis pendientes.'), findsOneWidget);
    expect(find.text('Todavía no hay vacunaciones registradas'), findsOneWidget);
  });

  testWidgets('Muestra las pendientes con su vencimiento y el botón Aplicar', (tester) async {
    final vencida = DateTime.now().subtract(const Duration(days: 3));
    String iso(DateTime f) => '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

    await abrir(
      tester,
      MockClient((request) async {
        if (request.url.path.endsWith('/resumen')) {
          return http.Response(jsonEncode({'vacunados': 1, 'pendientes': 1, 'vencidas': 1}), 200);
        }
        if (request.url.path.endsWith('/pendientes')) {
          return http.Response(
            jsonEncode([
              {
                'vacunacionId': 'v1',
                'animalId': 'a1',
                'arete': 'AR-001',
                'nombreAnimal': 'Luna',
                'vacunaId': 'x',
                'vacuna': 'Rabia bovina',
                'ultimaAplicacion': '2025-10-01',
                'fechaProximaDosis': iso(vencida),
                'vencida': true,
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );

    expect(find.text('AR-001 · Luna — Rabia bovina'), findsOneWidget);
    expect(find.text('Vencida hace 3 días'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Aplicar'), findsOneWidget);
  });
}
