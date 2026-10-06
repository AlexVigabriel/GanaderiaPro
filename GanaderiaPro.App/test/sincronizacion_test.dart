import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/almacen_local.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/conexion.dart';
import 'package:ganaderia_pro_app/core/pendientes.dart';
import 'package:ganaderia_pro_app/core/route_observer.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/features/ganado/listado_animales_screen.dart';
import 'package:ganaderia_pro_app/features/shell/app_shell.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _token(String ranchoId) {
  String parte(Map<String, dynamic> datos) => base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');
  return '${parte({'alg': 'HS256'})}.${parte({'ranchoId': ranchoId})}.firma';
}

DatosAnimal _datos(String arete) => DatosAnimal(arete: arete, sexo: 'Hembra', raza: 'Nelore');

// Simula /api/animales/lote: rechaza los aretes de [repetidos] (RN-01) y
// recuerda cada envío.
class _Servidor {
  _Servidor({this.repetidos = const {}});

  final Set<String> repetidos;
  final envios = <List<Map<String, dynamic>>>[];
  bool caido = false;

  Future<http.Response> responder(http.Request request) async {
    if (!request.url.path.endsWith('/lote')) {
      return http.Response(request.url.path.endsWith('/resumen') ? _resumen : '[]', 200);
    }
    final filas = (jsonDecode(request.body) as List<dynamic>).cast<Map<String, dynamic>>();
    envios.add(filas);
    if (caido) throw http.ClientException('se cortó');
    final rechazados = [
      for (var i = 0; i < filas.length; i++)
        if (repetidos.contains(filas[i]['arete']))
          {
            'fila': i + 1,
            'arete': filas[i]['arete'],
            'motivo': "Ya existe un animal con la identificación '${filas[i]['arete']}' en este rancho.",
          },
    ];
    final registrados = [
      for (final f in filas)
        if (!repetidos.contains(f['arete'])) {'arete': f['arete']},
    ];
    return http.Response(jsonEncode({'registrados': registrados, 'rechazados': rechazados}), 200);
  }

  static final _resumen = jsonEncode({
    'activos': 0,
    'hembrasActivas': 0,
    'machosActivos': 0,
    'vendidos': 0,
    'fallecidos': 0,
  });
}

void main() {
  late AlmacenPendientesMemoria almacen;
  final avisos = <String>[];
  final pendientes = RegistrosPendientes.instancia;

  setUp(() async {
    almacen = AlmacenPendientesMemoria();
    avisos.clear();
    pendientes
      ..almacen = almacen
      ..avisar = avisos.add;
    SesionActual.instancia.guardar(token: _token('r1'), nombreRancho: 'La Esperanza', nombreUsuario: 'Ana');
    EstadoConexion.instancia.informar(enLinea: true);
    await pendientes.cargar();
  });

  tearDown(() async {
    pendientes
      ..detenerSincronizacion()
      ..avisar = null;
    SesionActual.instancia.cerrar();
    EstadoConexion.instancia.informar(enLinea: true);
    await pendientes.cargar();
  });

  test('Envía los pendientes con su id local y avisa cuántos se sincronizaron', () async {
    await pendientes.guardar([_datos('OFF-001'), _datos('OFF-002')]);
    final ids = pendientes.animales.map((a) => a.idLocal).toList();
    final servidor = _Servidor();

    final enviados = await http.runWithClient(pendientes.sincronizar, () => MockClient(servidor.responder));

    expect(enviados, 2);
    expect(servidor.envios.single.map((f) => f['idCliente']), ids);
    expect(pendientes.animales, isEmpty);
    expect(EstadoConexion.instancia.pendientes, 0);
    expect(avisos, ['Conexión restaurada: 2 registros sincronizados']);
  });

  test('Un arete que ya existe queda en «Conflicto» con el motivo, sin descartarse (RN-01)', () async {
    await pendientes.guardar([_datos('OFF-001'), _datos('AR-001')]);
    final servidor = _Servidor(repetidos: {'AR-001'});

    await http.runWithClient(pendientes.sincronizar, () => MockClient(servidor.responder));

    final conflicto = pendientes.animales.single;
    expect(conflicto.datos.arete, 'AR-001');
    expect(conflicto.enConflicto, isTrue);
    expect(conflicto.motivo, "Ya existe un animal con la identificación 'AR-001' en este rancho.");
    expect(avisos, ['Conexión restaurada: 1 registro sincronizado · 1 con conflicto']);

    // Un conflicto no se vuelve a enviar solo.
    await http.runWithClient(pendientes.sincronizar, () => MockClient(servidor.responder));
    expect(servidor.envios.length, 1);

    // Corregido, vuelve a la cola y se reenvía.
    await http.runWithClient(() async {
      await pendientes.corregir(conflicto, _datos('AR-077'));
      await Future<void>.delayed(Duration.zero);
    }, () => MockClient(servidor.responder));
    expect(servidor.envios.last.single['arete'], 'AR-077');
    expect(servidor.envios.last.single['idCliente'], conflicto.idLocal);
    expect(pendientes.animales, isEmpty);
  });

  test('Si el envío falla, se reintenta con los mismos ids: el servidor no duplica', () async {
    await pendientes.guardar([_datos('OFF-001')]);
    final servidor = _Servidor()..caido = true;

    final primero = await http.runWithClient(pendientes.sincronizar, () => MockClient(servidor.responder));
    expect(primero, 0);
    expect(pendientes.animales.single.enConflicto, isFalse);
    expect(avisos, isEmpty);

    servidor.caido = false;
    // El fallo marcó "sin conexión"; vuelve.
    EstadoConexion.instancia.informar(enLinea: true);
    await http.runWithClient(pendientes.sincronizar, () => MockClient(servidor.responder));

    expect(servidor.envios.length, 2);
    expect(servidor.envios[1].single['idCliente'], servidor.envios[0].single['idCliente']);
    expect(pendientes.animales, isEmpty);
  });

  test('Sin conexión no intenta enviar', () async {
    await pendientes.guardar([_datos('OFF-001')]);
    EstadoConexion.instancia.informar(enLinea: false);
    final servidor = _Servidor();

    await http.runWithClient(pendientes.sincronizar, () => MockClient(servidor.responder));

    expect(servidor.envios, isEmpty);
    expect(pendientes.animales.length, 1);
  });

  testWidgets('Al volver la conexión envía solo, sin acción del usuario, antes de 30 segundos', (tester) async {
    final servidor = _Servidor();
    await http.runWithClient(() async {
      await pendientes.guardar([_datos('OFF-001')]);
      EstadoConexion.instancia.informar(enLinea: false);
      pendientes.iniciarSincronizacion();
      await tester.pump(const Duration(seconds: 15));
      expect(servidor.envios, isEmpty);

      EstadoConexion.instancia.informar(enLinea: true);
      await tester.pump(const Duration(seconds: 1));
      expect(servidor.envios.length, 1);
      expect(pendientes.animales, isEmpty);
      pendientes.detenerSincronizacion();
    }, () => MockClient(servidor.responder));
  });

  testWidgets('Mientras sincroniza, el aviso dice «Sincronizando» y al terminar desaparece', (tester) async {
    final estado = EstadoConexion()..pendientes = 2;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: Row(children: [IndicadorConexion(estado: estado)]),
        ),
      ),
    );

    estado.sincronizando = true;
    await tester.pump();
    expect(find.text('Sincronizando · 2 pendientes', findRichText: true), findsOneWidget);

    estado
      ..pendientes = 0
      ..sincronizando = false;
    await tester.pump();
    expect(find.textContaining('Sincronizando', findRichText: true), findsNothing);
  });

  testWidgets('El listado muestra el conflicto con el motivo y permite descartarlo', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pendientes.guardar([_datos('AR-001')]);
    await almacen.actualizar(
      pendientes.animales.single.conflicto("Ya existe un animal con la identificación 'AR-001' en este rancho."),
    );
    await pendientes.cargar();
    final servidor = _Servidor();

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.claro, navigatorObservers: [routeObserver], home: const ListadoAnimalesScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conflicto'), findsOneWidget);
      expect(
        find.text(
          "Ya existe un animal con la identificación 'AR-001' en este rancho. Corregí la identificación o descartalo.",
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Descartar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pumpAndSettle();
    }, () => MockClient(servidor.responder));

    expect(find.text('Conflicto'), findsNothing);
    expect(await almacen.listar('r1'), isEmpty);
  });
}
