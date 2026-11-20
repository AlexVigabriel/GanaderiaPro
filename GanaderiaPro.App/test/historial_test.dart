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

  testWidgets('RC-11: muestra seguimiento, diagnóstico de preñez, aborto, bajas y reactivaciones, y filtra por tipo', (tester) async {
    Map<String, dynamic> evento(String fecha, String tipo, String categoria, String descripcion) => {
      'fecha': fecha,
      'tipo': tipo,
      'categoria': categoria,
      'descripcion': descripcion,
      'usuario': 'Laura Rojas',
      'fechaRegistro': '${fecha}T12:00:00Z',
    };
    await abrirHistorial(
      tester,
      MockClient(
        (request) async => http.Response(
          jsonEncode([
            evento('2026-11-15', 'Reactivacion', 'Estado', 'Animal reactivado (antes: Vendido).'),
            evento('2026-11-12', 'Baja', 'Estado', 'Baja registrada: Vendido.'),
            evento('2026-11-10', 'FinTratamiento', 'Sanidad', 'Neumonía · resultado: Recuperado'),
            evento('2026-11-09', 'SeguimientoTratamiento', 'Sanidad', 'Neumonía (día 3 de 7): Mejora'),
            evento('2026-11-07', 'Tratamiento', 'Sanidad', 'Neumonía · Oxitetraciclina 10 ml, 7 días · finalizado: Recuperado'),
            evento('2026-10-01', 'Aborto', 'Reproduccion', 'Aborto: la preñez se cerró'),
            evento('2026-08-01', 'DiagnosticoPrenez', 'Reproduccion', 'Preñez confirmada'),
            evento('2026-07-01', 'Pesaje', 'Pesajes', '400 kg'),
            evento('2026-06-01', 'MovimientoCorral', 'Corrales', 'Entró al corral «Norte»'),
          ]),
          200,
        ),
      ),
    );

    expect(find.text('Seguimiento del tratamiento'), findsOneWidget);
    expect(find.text('Fin del tratamiento'), findsOneWidget);
    expect(find.text('Diagnóstico de preñez'), findsOneWidget);
    expect(find.text('Aborto'), findsOneWidget);
    expect(find.text('Entró al corral «Norte»'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Reproducción'));
    await tester.pumpAndSettle();
    expect(find.text('Aborto'), findsOneWidget);
    expect(find.text('Diagnóstico de preñez'), findsOneWidget);
    expect(find.text('Seguimiento del tratamiento'), findsNothing);
    expect(find.text('Pesaje'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sanidad'));
    await tester.pumpAndSettle();
    expect(find.text('Neumonía (día 3 de 7): Mejora'), findsOneWidget);
    expect(find.text('Aborto'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Corrales'));
    await tester.pumpAndSettle();
    expect(find.text('Entró al corral «Norte»'), findsOneWidget);
    expect(find.text('Tratamiento'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Estado'));
    await tester.pumpAndSettle();
    expect(find.text('Baja registrada: Vendido.'), findsOneWidget);
    expect(find.text('Reactivación'), findsOneWidget);
    expect(find.text('Entró al corral «Norte»'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
    await tester.pumpAndSettle();
    expect(find.text('400 kg'), findsOneWidget);
  });

  testWidgets('Sin eventos muestra «Sin registros»', (tester) async {
    await abrirHistorial(tester, MockClient((request) async => http.Response('[]', 200)));

    expect(find.text('Sin registros'), findsOneWidget);
  });
}
