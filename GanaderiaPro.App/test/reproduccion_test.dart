import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/reproduccion.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/core/validaciones_animal.dart';
import 'package:ganaderia_pro_app/features/ganado/reproduccion_animal.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Animal _vaca() => Animal(
  id: 'a1',
  arete: 'AR-010',
  sexo: 'Hembra',
  raza: 'Nelore',
  peso: 420,
  estado: 'Activo',
  fechaRegistro: DateTime(2026),
  fechaNacimiento: DateTime(2022, 3, 1),
);

String _iso(DateTime f) => DatosAnimal.fechaIso(f);

// Simula el servidor: guarda las preñeces en memoria.
class _Servidor {
  final preneces = <Map<String, dynamic>>[];
  final pedidos = <String>[];

  Future<http.Response> responder(http.Request request) async {
    pedidos.add('${request.method} ${request.url.path}');
    if (request.method == 'GET') return http.Response(jsonEncode(preneces), 200);
    final cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.url.path.endsWith('/parto')) {
      preneces.first
        ..['fechaParto'] = cuerpo['fechaParto']
        ..['abierta'] = false;
      return http.Response(jsonEncode(preneces.first), 200);
    }
    final servicio = DateTime.parse(cuerpo['fechaServicio'] as String);
    preneces.insert(0, {
      'id': 'p${preneces.length}',
      'fechaServicio': cuerpo['fechaServicio'],
      'fechaProbableParto': _iso(servicio.add(const Duration(days: 283))),
      'fechaParto': null,
      'abierta': true,
      'observacion': cuerpo['observacion'],
    });
    return http.Response(jsonEncode(preneces.first), 200);
  }
}

void main() {
  tearDown(SesionActual.instancia.cerrar);

  Future<void> mostrar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(body: SingleChildScrollView(child: TarjetaReproduccion(animal: _vaca()))),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Registra el servicio con la fecha de hoy y muestra el parto probable (RN-10)', (tester) async {
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');
    final servidor = _Servidor();

    await http.runWithClient(() async {
      await mostrar(tester);
      expect(find.text('Sin servicios registrados.'), findsOneWidget);

      await tester.tap(find.text('Registrar servicio'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Inseminación');
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar servicio').last);
      await tester.pumpAndSettle();
    }, () => MockClient(servidor.responder));

    final hoy = fechaDeHoy();
    expect(servidor.preneces.single['fechaServicio'], _iso(hoy));
    expect(servidor.preneces.single['observacion'], 'Inseminación');
    expect(find.text('Preñada'), findsOneWidget);
    expect(
      find.textContaining('Parto probable ${_dma(hoy.add(const Duration(days: 283)))} (faltan 283 días)'),
      findsOneWidget,
    );
    expect(find.text('Registrar parto'), findsOneWidget);
  });

  testWidgets('Registrar el parto cierra la preñez y vuelve a permitir un servicio', (tester) async {
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');
    final hoy = fechaDeHoy();
    final servicio = hoy.subtract(const Duration(days: 280));
    final servidor = _Servidor()
      ..preneces.add({
        'id': 'p0',
        'fechaServicio': _iso(servicio),
        'fechaProbableParto': _iso(servicio.add(const Duration(days: 283))),
        'fechaParto': null,
        'abierta': true,
        'observacion': null,
      });

    await http.runWithClient(() async {
      await mostrar(tester);
      expect(find.textContaining('faltan 3 días'), findsOneWidget);

      await tester.tap(find.text('Registrar parto'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar parto').last);
      await tester.pumpAndSettle();
    }, () => MockClient(servidor.responder));

    expect(servidor.pedidos, contains('POST /api/animales/a1/preneces/p0/parto'));
    expect(find.text('Preñada'), findsNothing);
    expect(find.textContaining('Parto ${_dma(hoy)}'), findsOneWidget);
    expect(find.text('Registrar servicio'), findsOneWidget);
  });

  testWidgets('Un rol con solo lectura ve la reproducción pero no puede registrar', (tester) async {
    SesionActual.instancia.guardar(
      token: 't',
      nombreRancho: 'R',
      nombreUsuario: 'Beto',
      rol: 'Socio',
      permisos: {'Reproduccion': 'Lectura'},
    );

    await http.runWithClient(() async {
      await mostrar(tester);
    }, () => MockClient(_Servidor().responder));

    expect(find.text('Reproducción'), findsOneWidget);
    expect(find.text('Registrar servicio'), findsNothing);
  });

  test('Describe cuánto falta para el parto', () {
    final hoy = DateTime(2026, 10, 15);
    expect(describirParto(DateTime(2026, 10, 15), hoy), 'parto probable hoy');
    expect(describirParto(DateTime(2026, 10, 16), hoy), 'falta 1 día');
    expect(describirParto(DateTime(2026, 10, 25), hoy), 'faltan 10 días');
    expect(describirParto(DateTime(2026, 10, 13), hoy), 'venció hace 2 días');
  });
}

String _dma(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
