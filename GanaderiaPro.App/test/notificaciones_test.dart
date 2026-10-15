import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/notificaciones.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/features/notificaciones/notificaciones_screen.dart';
import 'package:ganaderia_pro_app/features/shell/app_shell.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');
    notificacionesNoLeidas.value = 0;
  });
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

  // ---------------------------------------------------------------- HU-41
  Map<String, dynamic> n(String id, String tipo, String mensaje, {bool leida = false, String ref = 'Corral'}) => {
    'id': id,
    'tipo': tipo,
    'mensaje': mensaje,
    'referenciaTipo': ref,
    'referenciaId': 'r-$id',
    'leida': leida,
    'fecha': '2026-10-15T14:30:00Z',
  };

  // Simula el servidor del centro de notificaciones.
  Future<http.Response> Function(http.Request) servidor(List<Map<String, dynamic>> lista, List<String> pedidos) =>
      (request) async {
        pedidos.add('${request.method} ${request.url.path}');
        final ruta = request.url.path;
        if (ruta.endsWith('/cantidad')) {
          return http.Response(jsonEncode({'cantidad': lista.where((x) => x['leida'] == false).length}), 200);
        }
        if (request.method == 'POST') return http.Response('', 204);
        return http.Response(jsonEncode(lista), 200);
      };

  Future<void> abrirCentro(WidgetTester tester, Future<http.Response> Function(http.Request) s) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: const NotificacionesScreen(),
          onGenerateRoute: (r) => MaterialPageRoute(
            settings: r,
            builder: (_) => Scaffold(body: Text('Pantalla ${r.name}')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, () => MockClient(s));
  }

  testWidgets('El centro lista las notificaciones y marca todas como leídas (HU-41)', (tester) async {
    final pedidos = <String>[];
    final lista = [
      n('1', 'CorralLleno', 'El corral «Norte» está lleno (5/5).'),
      n('2', 'VacunaPendiente', 'AR-001: la próxima dosis de Fiebre aftosa vence el 18/10/2026.', ref: 'Animal'),
      n('3', 'PartoProximo', 'AR-010: parto probable el 25/10/2026.', leida: true, ref: 'Animal'),
    ];

    await http.runWithClient(() async {
      await abrirCentro(tester, servidor(lista, pedidos));
      expect(find.text('El corral «Norte» está lleno (5/5).'), findsOneWidget);
      expect(find.byKey(const ValueKey('sin-leer')), findsNWidgets(2));
      expect(notificacionesNoLeidas.value, 2);

      await tester.tap(find.text('Marcar todas como leídas'));
      await tester.pumpAndSettle();
    }, () => MockClient(servidor(lista, pedidos)));

    expect(pedidos, contains('POST /api/notificaciones/leidas'));
    expect(find.byKey(const ValueKey('sin-leer')), findsNothing);
    expect(find.text('Marcar todas como leídas'), findsNothing);
    expect(notificacionesNoLeidas.value, 0);
  });

  testWidgets('Abrir una notificación la marca como leída y lleva al registro', (tester) async {
    final pedidos = <String>[];
    final lista = [n('1', 'CorralLleno', 'El corral «Norte» está lleno (5/5).')];

    await http.runWithClient(() async {
      await abrirCentro(tester, servidor(lista, pedidos));
      await tester.tap(find.text('El corral «Norte» está lleno (5/5).'));
      await tester.pumpAndSettle();
    }, () => MockClient(servidor(lista, pedidos)));

    expect(pedidos, contains('POST /api/notificaciones/1/leida'));
    expect(find.text('Pantalla /corrales'), findsOneWidget);
  });

  testWidgets('Sin notificaciones muestra el aviso', (tester) async {
    await abrirCentro(tester, servidor([], []));

    expect(find.text('No tenés notificaciones'), findsOneWidget);
  });

  testWidgets('Tocar la campana abre el centro de notificaciones', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: const Scaffold(body: Center(child: CampanaNotificaciones())),
          onGenerateRoute: (r) => MaterialPageRoute(settings: r, builder: (_) => Text('Pantalla ${r.name}')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CampanaNotificaciones));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async => http.Response(jsonEncode({'cantidad': 1}), 200)));

    expect(find.text('Pantalla /notificaciones'), findsOneWidget);
  });
}
