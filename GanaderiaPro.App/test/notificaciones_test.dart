import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/features/shell/app_shell.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() => SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana'));
  tearDown(SesionActual.instancia.cerrar);

  Future<void> mostrar(WidgetTester tester, Future<http.Response> Function(http.Request) servidor) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: const Scaffold(body: Center(child: CampanaNotificaciones())),
        ),
      );
      await tester.pumpAndSettle();
    }, () => MockClient(servidor));
  }

  testWidgets('La campana muestra la cantidad de notificaciones sin leer (HU-40)', (tester) async {
    await mostrar(tester, (request) async {
      expect(request.url.path, '/api/notificaciones/no-leidas/cantidad');
      return http.Response(jsonEncode({'cantidad': 3}), 200);
    });

    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip('Notificaciones: 3 sin leer'), findsOneWidget);
  });

  testWidgets('Sin notificaciones no muestra número', (tester) async {
    await mostrar(tester, (request) async => http.Response(jsonEncode({'cantidad': 0}), 200));

    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('Con más de 99 sin leer muestra 99+', (tester) async {
    await mostrar(tester, (request) async => http.Response(jsonEncode({'cantidad': 150}), 200));

    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('Si el servidor no responde, la campana no falla', (tester) async {
    await mostrar(tester, (request) async => throw http.ClientException('sin red'));

    expect(find.byTooltip('Notificaciones'), findsOneWidget);
  });
}
