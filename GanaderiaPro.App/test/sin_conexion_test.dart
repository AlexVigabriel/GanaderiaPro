import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/almacen_local.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/boveda_sesion.dart';
import 'package:ganaderia_pro_app/core/conexion.dart';
import 'package:ganaderia_pro_app/core/pendientes.dart';
import 'package:ganaderia_pro_app/core/route_observer.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/core/widgets/componentes.dart';
import 'package:ganaderia_pro_app/features/ganado/carga_multiple_dialog.dart';
import 'package:ganaderia_pro_app/features/ganado/listado_animales_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Token con el rancho adentro, como los que manda el servidor.
String _token(String ranchoId) {
  String parte(Map<String, dynamic> datos) => base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');
  return '${parte({'alg': 'HS256'})}.${parte({'ranchoId': ranchoId})}.firma';
}

const _datos = DatosAnimal(arete: 'AR-900', sexo: 'Hembra', raza: 'Nelore', peso: 320);

Map<String, dynamic> _animalServidor(String id, String arete) => {
  'id': id,
  'arete': arete,
  'sexo': 'Hembra',
  'raza': 'Nelore',
  'peso': 300,
  'estado': 'Activo',
  'fechaRegistro': '2026-01-01',
  'categoria': 'Vaca',
};

void main() {
  late AlmacenPendientesMemoria almacen;

  setUp(() async {
    almacen = AlmacenPendientesMemoria();
    RegistrosPendientes.instancia.almacen = almacen;
    SesionActual.instancia.guardar(token: _token('r1'), nombreRancho: 'La Esperanza', nombreUsuario: 'Ana');
    await RegistrosPendientes.instancia.cargar();
  });

  tearDown(() async {
    SesionActual.instancia
      ..boveda = null
      ..cerrar();
    EstadoConexion.instancia.informar(enLinea: true);
    await RegistrosPendientes.instancia.cargar();
  });

  test('La sesión queda guardada y se recupera al volver a abrir la app', () async {
    final boveda = BovedaMemoria();
    SesionActual.instancia
      ..boveda = boveda
      ..guardar(
        token: _token('r1'),
        nombreRancho: 'La Esperanza',
        nombreUsuario: 'Ana',
        rol: 'Veterinario',
        permisos: {'Ganado': 'Lectura'},
      );
    await Future<void>.delayed(Duration.zero);

    // "Cerrar la app": se pierde la memoria, la bóveda queda.
    SesionActual.instancia
      ..boveda = null
      ..cerrar()
      ..boveda = boveda;
    expect(SesionActual.instancia.estaAutenticado, isFalse);

    await SesionActual.instancia.restaurar();
    expect(SesionActual.instancia.estaAutenticado, isTrue);
    expect(SesionActual.instancia.nombreUsuario, 'Ana');
    expect(SesionActual.instancia.rol, 'Veterinario');
    expect(SesionActual.instancia.puedeVer('Ganado'), isTrue);
    expect(SesionActual.instancia.ranchoId, 'r1');

    // Cerrar sesión la borra del dispositivo.
    SesionActual.instancia.cerrar();
    await Future<void>.delayed(Duration.zero);
    expect(boveda.valor, isNull);
  });

  test('Los pendientes se conservan al volver a abrir la app y cuentan en el aviso', () async {
    await RegistrosPendientes.instancia.guardar([_datos]);
    expect(EstadoConexion.instancia.pendientes, 1);

    // "Volver a abrir": se vuelve a leer del almacén del dispositivo.
    RegistrosPendientes.instancia.almacen = almacen;
    await RegistrosPendientes.instancia.cargar();
    expect(RegistrosPendientes.instancia.animales.single.datos.arete, 'AR-900');
    expect(RegistrosPendientes.instancia.animales.single.idLocal, matches(RegExp(r'^[0-9a-f-]{36}$')));

    // Otro rancho en el mismo dispositivo no los ve (RN-16).
    SesionActual.instancia.guardar(token: _token('r2'), nombreRancho: 'Otro', nombreUsuario: 'Beto');
    await RegistrosPendientes.instancia.cargar();
    expect(RegistrosPendientes.instancia.animales, isEmpty);
    expect(EstadoConexion.instancia.pendientes, 0);
  });

  group('Carga de animales sin conexión', () {
    Future<AltaAnimales?> cargarUnAnimal(WidgetTester tester, String arete) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      AltaAnimales? resultado;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => resultado = await abrirCargaMultiple(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sin conexión: los animales se guardarán en este dispositivo y se enviarán al volver la conexión.'),
        findsOneWidget,
      );

      // Valores por defecto: sexo, raza y nacimiento (hoy).
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hembra').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nelore').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CampoFecha).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, arete);
      await tester.pump();
      await tester.tap(find.text('Cargar 1 animal'));
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('El alta se guarda en el dispositivo sin llamar al servidor', (tester) async {
      EstadoConexion.instancia.informar(enLinea: false);
      var llamadas = 0;

      await http.runWithClient(
        () async {
          final alta = await cargarUnAnimal(tester, 'AR-901');
          expect(alta, (registrados: 0, sinConexion: 1));
        },
        () => MockClient((request) async {
          llamadas++;
          return http.Response('', 500);
        }),
      );

      expect(llamadas, 0);
      final guardados = await almacen.listar('r1');
      expect(guardados.single.datos.arete, 'AR-901');
      expect(guardados.single.datos.raza, 'Nelore');
    });

    testWidgets('No deja repetir una identificación que ya espera sincronizarse (RN-01)', (tester) async {
      await RegistrosPendientes.instancia.guardar([_datos]);
      EstadoConexion.instancia.informar(enLinea: false);

      await cargarUnAnimal(tester, 'AR-900');

      expect(find.text('Ya está pendiente de sincronizar'), findsOneWidget);
      expect((await almacen.listar('r1')).length, 1);
    });
  });

  group('Listado sin conexión', () {
    Future<void> abrirListado(WidgetTester tester, http.Client Function() cliente) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.claro, navigatorObservers: [routeObserver], home: const ListadoAnimalesScreen()),
        );
        await tester.pumpAndSettle();
      }, cliente);
    }

    testWidgets('Muestra los registros del dispositivo marcados «Pendiente de sincronizar»', (tester) async {
      await RegistrosPendientes.instancia.guardar([_datos]);

      await abrirListado(tester, () => MockClient((request) async => throw http.ClientException('sin red')));

      expect(EstadoConexion.instancia.enLinea, isFalse);
      expect(find.text('Sin conexión: se muestran solo los registros pendientes.'), findsOneWidget);
      expect(find.text('AR-900'), findsOneWidget);
      expect(find.text('Pendiente de sincronizar'), findsOneWidget);
    });

    testWidgets('Sin conexión, editar, dar de baja y eliminar quedan deshabilitados (RN-13)', (tester) async {
      await abrirListado(
        tester,
        () => MockClient((request) async {
          if (request.url.path.endsWith('/resumen')) {
            return http.Response(
              jsonEncode({'activos': 1, 'hembrasActivas': 1, 'machosActivos': 0, 'vendidos': 0, 'fallecidos': 0}),
              200,
            );
          }
          return http.Response(jsonEncode([_animalServidor('a1', 'AR-001')]), 200);
        }),
      );
      expect(find.byTooltip('Editar'), findsOneWidget);

      EstadoConexion.instancia.informar(enLinea: false);
      await tester.pump();

      for (final accion in ['Editar', 'Registrar baja', 'Eliminar']) {
        final boton = find.byTooltip('$accion · Requiere conexión');
        expect(boton, findsOneWidget, reason: accion);
      }
      // Agregar animales sigue disponible: sin conexión se pueden dar altas.
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Agregar animales')).onPressed, isNotNull);
    });
  });
}
