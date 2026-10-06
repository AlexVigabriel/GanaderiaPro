import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/cerrar_sesion.dart';
import 'package:ganaderia_pro_app/core/conexion.dart';
import 'package:ganaderia_pro_app/features/shell/app_shell.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<void> mostrar(WidgetTester tester, EstadoConexion estado) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: Row(children: [IndicadorConexion(estado: estado)]),
        ),
      ),
    );
  }

  testWidgets('Sin conexión muestra el aviso con los pendientes y al volver desaparece', (tester) async {
    final estado = EstadoConexion();
    await mostrar(tester, estado);
    expect(find.textContaining('Sin conexión'), findsNothing);

    estado
      ..pendientes = 3
      ..informar(enLinea: false);
    await tester.pump();
    expect(find.text('Sin conexión · 3 pendientes', findRichText: true), findsOneWidget);

    estado.pendientes = 1;
    await tester.pump();
    expect(find.text('Sin conexión · 1 pendiente', findRichText: true), findsOneWidget);

    estado.informar(enLinea: true);
    await tester.pump();
    expect(find.textContaining('Sin conexión', findRichText: true), findsNothing);
  });

  testWidgets('Si el servidor deja de responder, el aviso aparece antes de 5 segundos', (tester) async {
    final estado = EstadoConexion();
    var servidorResponde = true;

    await http.runWithClient(
      () async {
        await mostrar(tester, estado);
        estado.iniciar();
        await tester.pump();
        expect(estado.enLinea, isTrue);

        // Se corta: los pedidos quedan colgados, sin respuesta.
        servidorResponde = false;
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('Sin conexión · 0 pendientes', findRichText: true), findsOneWidget);

        // Vuelve: el aviso se va en la siguiente pregunta.
        servidorResponde = true;
        await tester.pump(const Duration(seconds: 3));
        expect(find.textContaining('Sin conexión', findRichText: true), findsNothing);
        estado.detener();
      },
      () => MockClient((request) async {
        if (!servidorResponde) return Completer<http.Response>().future;
        return http.Response('', 204);
      }),
    );
  });

  test('Un pedido que falla por red avisa al momento que no hay conexión', () async {
    addTearDown(() => EstadoConexion.instancia.informar(enLinea: true));
    final cliente = ClienteConSesion(MockClient((request) async => throw http.ClientException('sin red')));

    await expectLater(cliente.get(Uri.parse('http://servidor/api/animales')), throwsA(isA<http.ClientException>()));
    expect(EstadoConexion.instancia.enLinea, isFalse);

    final otro = ClienteConSesion(MockClient((request) async => http.Response('[]', 200)));
    await otro.get(Uri.parse('http://servidor/api/animales'));
    expect(EstadoConexion.instancia.enLinea, isTrue);
  });
}
