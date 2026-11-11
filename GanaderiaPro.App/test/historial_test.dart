import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/features/ganado/historial_animal.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// HU-22: línea de tiempo del animal en su ficha.
final _animal = Animal.fromJson({
  'id': 'a1',
  'arete': 'H-01',
  'sexo': 'Hembra',
  'raza': 'Nelore',
  'estado': 'Activo',
  'fechaRegistro': '2026-10-01T12:00:00Z',
  'fechaNacimiento': '2022-11-02',
});

void main() {
  setUp(() => SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana'));
  tearDown(SesionActual.instancia.cerrar);

  Future<void> abrirHistorial(WidgetTester tester, MockClient servidor) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Scaffold(body: SingleChildScrollView(child: TarjetaHistorial(animal: _animal))),
        ),
      );
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
    }, () => servidor);
  }

  testWidgets('No pide nada al servidor hasta que se abre', (tester) async {
    var pedidos = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: Scaffold(body: TarjetaHistorial(animal: _animal))));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      pedidos++;
      return http.Response('[]', 200);
    }));

    expect(pedidos, 0);
  });

  testWidgets('Muestra los eventos con tipo, fecha y quién los registró', (tester) async {
    await abrirHistorial(
      tester,
      MockClient((request) async {
        expect(request.url.path, endsWith('/api/animales/a1/historial'));
        return http.Response(
          jsonEncode([
            {
              'fecha': '2026-11-02',
              'tipo': 'MovimientoCorral',
              'descripcion': 'Pasó del corral «Norte» a «Sur»',
              'usuario': 'Laura Rojas',
              'fechaRegistro': '2026-11-02T15:00:00Z',
            },
            {
              'fecha': '2026-09-15',
              'tipo': 'Pesaje',
              'descripcion': '420.5 kg',
              'usuario': null,
              'fechaRegistro': '2026-09-15T12:00:00Z',
            },
          ]),
          200,
        );
      }),
    );

    expect(find.text('Movimiento de corral'), findsOneWidget);
    expect(find.text('Pasó del corral «Norte» a «Sur»'), findsOneWidget);
    expect(find.text('02/11/2026 · Laura Rojas'), findsOneWidget);
    expect(find.text('Pesaje'), findsOneWidget);
    expect(find.text('15/09/2026'), findsOneWidget);
  });

  testWidgets('Sin eventos muestra «Sin registros»', (tester) async {
    await abrirHistorial(tester, MockClient((request) async => http.Response('[]', 200)));

    expect(find.text('Sin registros'), findsOneWidget);
  });
}
