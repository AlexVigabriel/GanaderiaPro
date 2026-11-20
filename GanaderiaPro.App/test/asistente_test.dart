import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/features/asistente/asistente_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// HU-36.1 y HU-38: pantalla del asistente de consultas.
void main() {
  setUp(() => SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana'));
  tearDown(SesionActual.instancia.cerrar);

  Future<http.Response> servidor(http.Request request, {required Map<String, dynamic> respuesta}) async {
    if (request.url.path.endsWith('/asistente/ejemplos')) {
      return http.Response(jsonEncode(['¿Cuántos animales hay?', '¿Cuál es el peso promedio?']), 200);
    }
    if (request.url.path.endsWith('/asistente')) {
      // Como el servidor real: JSON en UTF-8 (la respuesta puede traer «•»).
      return http.Response.bytes(utf8.encode(jsonEncode(respuesta)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return http.Response('{}', 404);
  }

  Future<void> abrir(WidgetTester tester, MockClient cliente, Future<void> Function() acciones) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const AsistenteScreen()));
      await tester.pumpAndSettle();
      await acciones();
    }, () => cliente);
  }

  testWidgets('Muestra las preguntas soportadas y responde al tocar una', (tester) async {
    String? preguntaEnviada;
    await abrir(
      tester,
      MockClient((request) {
        if (request.url.path.endsWith('/asistente')) preguntaEnviada = request.url.queryParameters['pregunta'];
        return servidor(request, respuesta: {
          'respuesta': 'Hay 3 animales activos.',
          'reconocida': true,
          'sinDatos': false,
          'responsable': null,
          'ejemplos': <String>[],
        });
      }),
      () async {
        expect(find.text('¿Cuántos animales hay?'), findsOneWidget);
        await tester.tap(find.text('¿Cuántos animales hay?'));
        await tester.pumpAndSettle();
      },
    );

    expect(preguntaEnviada, '¿Cuántos animales hay?');
    expect(find.text('Hay 3 animales activos.'), findsOneWidget);
  });

  testWidgets('Separa las preguntas frecuentes de la consulta propia (RC-04)', (tester) async {
    await abrir(
      tester,
      MockClient((request) => servidor(request, respuesta: const {})),
      () async {},
    );

    expect(find.text('Preguntas frecuentes'), findsOneWidget);
    expect(find.text('Tu consulta'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '¿Cuántos animales hay?'), findsOneWidget);
  });

  testWidgets('Muestra una respuesta por grupos en varias líneas (RC-05)', (tester) async {
    const texto = 'Animales activos por raza (3 en total):\n• Nelore: 2\n• Brahman: 1';
    await abrir(
      tester,
      MockClient((request) => servidor(request, respuesta: {
        'respuesta': texto,
        'reconocida': true,
        'sinDatos': false,
        'responsable': null,
        'ejemplos': <String>[],
      })),
      () async {
        await tester.enterText(find.byType(TextField), '¿Cuántos animales hay por raza?');
        await tester.tap(find.byTooltip('Enviar'));
        await tester.pumpAndSettle();
      },
    );

    expect(find.text(texto), findsOneWidget);
  });

  testWidgets('Si no entiende, ofrece ejemplos en vez de inventar', (tester) async {
    await abrir(
      tester,
      MockClient((request) => servidor(request, respuesta: {
        'respuesta': 'No entendí la pregunta. Probá con alguna de estas:',
        'reconocida': false,
        'sinDatos': false,
        'responsable': null,
        'ejemplos': ['¿Cuántos corrales hay?'],
      })),
      () async {
        await tester.enterText(find.byType(TextField), '¿Va a llover?');
        await tester.tap(find.byTooltip('Enviar'));
        await tester.pumpAndSettle();
      },
    );

    expect(find.text('¿Va a llover?'), findsOneWidget);
    expect(find.text('No entendí la pregunta. Probá con alguna de estas:'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '¿Cuántos corrales hay?'), findsOneWidget);
  });

  testWidgets('Un dato faltante muestra al responsable', (tester) async {
    const texto =
        'No encontramos información actualizada sobre este dato. Responsable de registrarlo: Laura Rojas (Veterinario). Ya le avisamos.';
    await abrir(
      tester,
      MockClient((request) => servidor(request, respuesta: {
        'respuesta': texto,
        'reconocida': true,
        'sinDatos': true,
        'responsable': 'Laura Rojas',
        'ejemplos': <String>[],
      })),
      () async {
        await tester.enterText(find.byType(TextField), '¿Cuándo se vacunó el AR-003?');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();
      },
    );

    expect(find.text(texto), findsOneWidget);
  });
}
