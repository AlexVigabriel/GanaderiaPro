import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/core/tablero.dart';
import 'package:ganaderia_pro_app/core/widgets/componentes.dart';
import 'package:ganaderia_pro_app/features/shell/home_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// HU-12: indicadores generales del rancho en el tablero.
Map<String, dynamic> _resumen({
  int activos = 0,
  int machos = 0,
  int hembras = 0,
  int vacunados = 0,
  int pendientes = 0,
  int aParir = 0,
  int fallecidos = 0,
  int corrales = 0,
}) =>
    {
      'animalesActivos': activos,
      'machosActivos': machos,
      'hembrasActivas': hembras,
      'vacunados': vacunados,
      'vacunacionesPendientes': pendientes,
      'proximasAParir': aParir,
      'fallecidosDelAnio': fallecidos,
      'corralesActivos': corrales,
    };

void main() {
  setUp(() => SesionActual.instancia.guardar(token: 't', nombreRancho: 'Estancia', nombreUsuario: 'Ana Vega'));
  tearDown(SesionActual.instancia.cerrar);

  Future<void> abrir(WidgetTester tester, MockClient servidor) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const HomeScreen()));
      await tester.pumpAndSettle();
    }, () => servidor);
  }

  int valorDe(WidgetTester tester, String etiqueta) => tester
      .widget<TarjetaIndicador>(find.byWidgetPredicate((w) => w is TarjetaIndicador && w.etiqueta == etiqueta))
      .valor!;

  test('Lee el resumen del servidor', () {
    final r = ResumenTablero.fromJson(_resumen(activos: 10, machos: 4, hembras: 6, corrales: 2));
    expect(r.animalesActivos, 10);
    expect(r.machosActivos, 4);
    expect(r.hembrasActivas, 6);
    expect(r.corralesActivos, 2);
  });

  testWidgets('Muestra los ocho indicadores con los valores del servidor', (tester) async {
    await abrir(
      tester,
      MockClient((request) async {
        if (request.url.path.endsWith('/tablero/resumen')) {
          return http.Response(
            jsonEncode(_resumen(
              activos: 10,
              machos: 4,
              hembras: 6,
              vacunados: 7,
              pendientes: 3,
              aParir: 2,
              fallecidos: 1,
              corrales: 5,
            )),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );

    expect(find.byType(TarjetaIndicador), findsNWidgets(8));
    expect(valorDe(tester, 'Animales activos'), 10);
    expect(valorDe(tester, 'Machos activos'), 4);
    expect(valorDe(tester, 'Hembras activas'), 6);
    expect(valorDe(tester, 'Vacunados'), 7);
    expect(valorDe(tester, 'Vacunaciones pendientes'), 3);
    expect(valorDe(tester, 'Próximas a parir'), 2);
    expect(valorDe(tester, 'Fallecidos del año'), 1);
    expect(valorDe(tester, 'Corrales activos'), 5);
  });

  testWidgets('Sin registros, todos los indicadores muestran 0 sin errores', (tester) async {
    await abrir(
      tester,
      MockClient((request) async => request.url.path.endsWith('/tablero/resumen')
          ? http.Response(jsonEncode(_resumen()), 200)
          : http.Response('{}', 404)),
    );

    expect(find.byType(TarjetaIndicador), findsNWidgets(8));
    final tarjetas = tester.widgetList<TarjetaIndicador>(find.byType(TarjetaIndicador));
    expect(tarjetas.map((t) => t.valor), everyElement(0));
    expect(find.text('No se pudieron cargar los indicadores.'), findsNothing);
  });

  testWidgets('Si el servidor falla, avisa y permite reintentar', (tester) async {
    var intentos = 0;
    final servidor = MockClient((request) async {
      if (!request.url.path.endsWith('/tablero/resumen')) return http.Response('{}', 404);
      intentos++;
      return intentos == 1 ? http.Response('{}', 500) : http.Response(jsonEncode(_resumen(activos: 4)), 200);
    });
    await abrir(tester, servidor);

    expect(find.text('No se pudieron cargar los indicadores.'), findsOneWidget);

    await http.runWithClient(() async {
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
    }, () => servidor);

    expect(find.text('No se pudieron cargar los indicadores.'), findsNothing);
    expect(valorDe(tester, 'Animales activos'), 4);
  });
}
