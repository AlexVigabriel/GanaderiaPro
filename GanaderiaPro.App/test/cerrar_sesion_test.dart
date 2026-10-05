import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() => SesionActual.instancia.guardar(token: 't1', nombreRancho: 'Estancia La Esperanza', nombreUsuario: 'Ana Vega'));
  tearDown(SesionActual.instancia.cerrar);

  Future<void> abrirEn(WidgetTester tester, String ruta) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.binding.platformDispatcher.defaultRouteNameTestValue = ruta;
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(const GanaderiaProApp());
    await tester.pumpAndSettle();
  }

  bool sePuedeVolver(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first).canPop();

  testWidgets('Cerrar sesión desde el menú de perfil avisa al servidor y vuelve al login', (tester) async {
    final pedidos = <String>[];

    await http.runWithClient(() async {
      await abrirEn(tester, '/ganado');

      await tester.tap(find.byTooltip('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Vega'), findsOneWidget);
      await tester.tap(find.text('Cerrar sesión').last);
      await tester.pumpAndSettle();

      expect(pedidos, contains('POST /api/auth/cerrar-sesion'));
      expect(SesionActual.instancia.estaAutenticado, isFalse);
      expect(find.text('Ingresar'), findsOneWidget);
      // HU-52: "Atrás" no lleva a ninguna pantalla protegida.
      expect(sePuedeVolver(tester), isFalse);
    }, () => MockClient((request) async {
      pedidos.add('${request.method} ${request.url.path}');
      return http.Response('', 204);
    }));
  });

  testWidgets('Si el servidor rechaza la sesión (401), la app vuelve al login', (tester) async {
    await http.runWithClient(() async {
      await abrirEn(tester, '/ganado');

      expect(SesionActual.instancia.estaAutenticado, isFalse);
      expect(find.text('Ingresar'), findsOneWidget);
      expect(find.text('Tu sesión se cerró. Iniciá sesión de nuevo.'), findsOneWidget);
    }, () => MockClient((request) async => http.Response(jsonEncode({}), 401)));
  });
}
