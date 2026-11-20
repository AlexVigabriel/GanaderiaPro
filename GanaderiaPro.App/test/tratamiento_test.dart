import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/sanidad.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/core/validaciones_animal.dart';
import 'package:ganaderia_pro_app/features/sanidad/tratamientos_widgets.dart';
import 'package:ganaderia_pro_app/features/sanidad/vacunaciones_widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Animal _animal() => Animal(
  id: 'a1',
  arete: 'AR-020',
  sexo: 'Macho',
  raza: 'Brahman',
  peso: 380,
  estado: 'Activo',
  fechaRegistro: DateTime(2026),
  fechaNacimiento: DateTime(2024, 5, 1),
);

String _iso(DateTime f) => DatosAnimal.fechaIso(f);

Map<String, dynamic> _tratamiento(
  String diagnostico,
  DateTime inicio,
  int dias, {
  String estado = 'EnCurso',
  String? resultado,
  List<Map<String, dynamic>> seguimientos = const [],
}) {
  final hoy = fechaDeHoy();
  final dia = (hoy.difference(inicio).inDays + 1).clamp(1, dias);
  return {
    'id': 't-${diagnostico.replaceAll(RegExp('[^A-Za-z]'), '')}',
    'animalId': 'a1',
    'arete': 'AR-020',
    'nombreAnimal': null,
    'diagnostico': diagnostico,
    'medicamento': 'Oxitetraciclina',
    'dosis': '10 ml',
    'fechaInicio': _iso(inicio),
    'duracionDias': dias,
    'fechaFin': _iso(inicio.add(Duration(days: dias - 1))),
    'enCurso': estado == 'EnCurso',
    'estado': estado,
    'diaActual': dia,
    'resultado': resultado,
    'fechaFinalizacion': resultado == null ? null : _iso(hoy),
    'observacion': null,
    'veterinario': 'Dra. Rojas',
    'seguimientos': seguimientos,
  };
}

Map<String, dynamic> _seguimiento(DateTime fecha, String evolucion, {String? nota}) => {
  'id': 's-${_iso(fecha)}',
  'fecha': _iso(fecha),
  'evolucion': evolucion,
  'nota': nota,
  'usuario': 'Dra. Rojas',
};

// Simula el servidor: vacunaciones vacías y tratamientos en memoria.
class _Servidor {
  final tratamientos = <Map<String, dynamic>>[];
  Map<String, dynamic>? enviado;
  String? ultimaRuta;

  Future<http.Response> responder(http.Request request) async {
    final ruta = request.url.path;
    if (request.method == 'POST') {
      ultimaRuta = ruta;
      enviado = jsonDecode(request.body) as Map<String, dynamic>;
    }
    if (ruta.endsWith('/seguimientos')) {
      final t = tratamientos.first;
      (t['seguimientos'] as List).add(
        _seguimiento(DateTime.parse(enviado!['fecha'] as String), enviado!['evolucion'] as String, nota: enviado!['nota'] as String?),
      );
      return http.Response(jsonEncode(t), 200);
    }
    if (ruta.endsWith('/finalizar')) {
      final t = tratamientos.first
        ..['estado'] = 'Finalizado'
        ..['enCurso'] = false
        ..['resultado'] = enviado!['resultado']
        ..['fechaFinalizacion'] = enviado!['fecha'];
      return http.Response(jsonEncode(t), 200);
    }
    if (ruta.endsWith('/tratamientos')) {
      if (request.method == 'POST') {
        final inicio = DateTime.parse(enviado!['fechaInicio'] as String);
        tratamientos.insert(0, _tratamiento(enviado!['diagnostico'] as String, inicio, enviado!['duracionDias'] as int));
        return http.Response(jsonEncode(tratamientos.first), 200);
      }
      // Lista del rancho (RC-09): ?terminados=true|false.
      if (ruta == '/api/tratamientos') {
        final terminados = request.url.queryParameters['terminados'] == 'true';
        return http.Response(
          jsonEncode(tratamientos.where((t) => (t['estado'] != 'EnCurso') == terminados).toList()),
          200,
        );
      }
      return http.Response(jsonEncode(tratamientos), 200);
    }
    return http.Response('[]', 200);
  }
}

void main() {
  setUp(() => SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana'));
  tearDown(SesionActual.instancia.cerrar);

  Future<void> mostrar(WidgetTester tester, Widget hijo) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(body: SingleChildScrollView(child: hijo)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> mostrarFicha(WidgetTester tester) => mostrar(tester, TarjetaHistorialSanitario(animal: _animal()));

  Future<void> elegirUnidad(WidgetTester tester, String unidad) async {
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Unidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(unidad).last);
    await tester.pumpAndSettle();
  }

  testWidgets('RC-08: registra un tratamiento con diagnóstico y dosis con unidad; aparece «En curso»', (tester) async {
    final servidor = _Servidor();

    await http.runWithClient(() async {
      await mostrarFicha(tester);
      expect(find.text('Este animal no tiene tratamientos registrados.'), findsOneWidget);

      await tester.tap(find.text('Registrar tratamiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar tratamiento'));
      await tester.pumpAndSettle();
      expect(find.text('El diagnóstico es obligatorio'), findsOneWidget);
      expect(find.text('El medicamento es obligatorio'), findsOneWidget);
      expect(find.text('Escribí la cantidad'), findsOneWidget);
      expect(find.text('Elegí la unidad'), findsOneWidget);
      expect(find.text('De 1 a 365 días'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Diagnóstico'), 'Neumonía');
      await tester.enterText(find.widgetWithText(TextField, 'Medicamento'), 'Oxitetraciclina');
      await tester.enterText(find.widgetWithText(TextField, 'Dosis'), '10');
      await tester.enterText(find.widgetWithText(TextField, 'Duración'), '5');
      // «10» sin unidad no se acepta.
      await tester.tap(find.text('Guardar tratamiento'));
      await tester.pumpAndSettle();
      expect(find.text('Elegí la unidad'), findsOneWidget);
      expect(servidor.enviado, isNull);

      await elegirUnidad(tester, 'ml');
      await tester.tap(find.text('Guardar tratamiento'));
      await tester.pumpAndSettle();
    }, () => MockClient(servidor.responder));

    expect(servidor.enviado, {
      'diagnostico': 'Neumonía',
      'medicamento': 'Oxitetraciclina',
      'dosis': '10 ml',
      'fechaInicio': _iso(fechaDeHoy()),
      'duracionDias': 5,
      'observacion': null,
    });
    expect(find.text('Neumonía · Oxitetraciclina (10 ml)'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
  });

  testWidgets('RC-08: la observación acepta hasta 300 caracteres y debe describir algo', (tester) async {
    await http.runWithClient(() async {
      await mostrarFicha(tester);
      await tester.tap(find.text('Registrar tratamiento'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Observaciones (opcional)'), '38');
      await tester.tap(find.text('Guardar tratamiento'));
      await tester.pumpAndSettle();
    }, () => MockClient(_Servidor().responder));

    expect(find.text('Debe describir algo, no solo un número'), findsOneWidget);
  });

  test('RC-08: armar la dosis y validar la cantidad', () {
    expect(armarDosis('5', 'ml'), '5 ml');
    expect(armarDosis('1', 'comprimidos'), '1 comprimido');
    expect(armarDosis('2,5', 'mg'), '2,5 mg');
    expect(validarCantidadDosis(''), isNotNull);
    expect(validarCantidadDosis('0'), 'Mayor que cero');
    expect(validarCantidadDosis('5.5.5'), isNotNull);
    expect(validarCantidadDosis('2,5'), isNull);
  });

  testWidgets('RC-09: el detalle muestra «Día 3 de 7» y los seguimientos; se registra uno nuevo', (tester) async {
    final hoy = fechaDeHoy();
    final inicio = hoy.subtract(const Duration(days: 2));
    final servidor = _Servidor()
      ..tratamientos.add(
        _tratamiento('Neumonía', inicio, 7, seguimientos: [_seguimiento(inicio, 'SinCambios', nota: 'Tose bastante')]),
      );

    await http.runWithClient(() async {
      await mostrarFicha(tester);
      expect(find.textContaining('Día 3 de 7'), findsOneWidget);

      await tester.tap(find.text('Neumonía · Oxitetraciclina (10 ml)'));
      await tester.pumpAndSettle();
      expect(find.text('Día 3 de 7'), findsOneWidget);
      expect(find.text('Tose bastante'), findsOneWidget);

      await tester.tap(find.text('Registrar seguimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar seguimiento'));
      await tester.pumpAndSettle();
      expect(find.text('Elegí cómo evolucionó'), findsOneWidget);

      await tester.tap(find.text('Mejora'));
      await tester.enterText(find.widgetWithText(TextField, 'Nota (opcional)'), 'Come mejor');
      await tester.tap(find.text('Guardar seguimiento'));
      await tester.pumpAndSettle();
    }, () => MockClient(servidor.responder));

    expect(servidor.ultimaRuta, '/api/animales/a1/tratamientos/t-Neumona/seguimientos');
    expect(servidor.enviado, {'fecha': _iso(hoy), 'evolucion': 'Mejora', 'nota': 'Come mejor'});
    expect(find.text('Come mejor'), findsOneWidget);
    expect(find.textContaining('Día 3 · '), findsOneWidget);
  });

  testWidgets('RC-09: se finaliza con un resultado antes del último día', (tester) async {
    final inicio = fechaDeHoy().subtract(const Duration(days: 1));
    final servidor = _Servidor()..tratamientos.add(_tratamiento('Diarrea', inicio, 7));

    await http.runWithClient(() async {
      await mostrarFicha(tester);
      await tester.tap(find.text('Diarrea · Oxitetraciclina (10 ml)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalizar tratamiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recuperado'));
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar seguimiento'), findsNothing);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
    }, () => MockClient(servidor.responder));

    expect(servidor.enviado, {'fecha': _iso(fechaDeHoy()), 'resultado': 'Recuperado'});
    // Al cerrar, la ficha vuelve a pedir la lista: figura como terminado.
    expect(find.text('Recuperado'), findsOneWidget);
    expect(find.text('En curso'), findsNothing);
  });

  testWidgets('RC-09: sin resultado al pasar el último día; en la ficha se separan en curso y terminados', (tester) async {
    final hoy = fechaDeHoy();
    final servidor = _Servidor()
      ..tratamientos.addAll([
        _tratamiento('Neumonía', hoy, 5),
        _tratamiento('Diarrea', DateTime(2026, 9, 1), 3, estado: 'SinResultado'),
      ]);

    await http.runWithClient(() async {
      await mostrarFicha(tester);
    }, () => MockClient(servidor.responder));

    expect(find.text('En curso (1)'), findsOneWidget);
    expect(find.text('Terminados (1)'), findsOneWidget);
    expect(find.text('Sin resultado'), findsOneWidget);
    expect(find.textContaining('01/09/2026 al 03/09/2026 · 3 días · Dra. Rojas'), findsOneWidget);
  });

  testWidgets('RC-09: en Sanidad, la tarjeta del rancho separa «En curso» de «Terminados»', (tester) async {
    final servidor = _Servidor()
      ..tratamientos.addAll([
        _tratamiento('Neumonía', fechaDeHoy(), 5),
        _tratamiento('Mastitis', DateTime(2026, 9, 1), 3, estado: 'Finalizado', resultado: 'Derivado'),
      ]);

    await http.runWithClient(() async {
      await mostrar(tester, const TarjetaTratamientosRancho(puedeEditar: true));
      expect(find.text('Neumonía · Oxitetraciclina (10 ml)'), findsOneWidget);
      expect(find.text('Mastitis · Oxitetraciclina (10 ml)'), findsNothing);

      await tester.tap(find.text('Terminados'));
      await tester.pumpAndSettle();
    }, () => MockClient(servidor.responder));

    expect(find.text('Mastitis · Oxitetraciclina (10 ml)'), findsOneWidget);
    expect(find.text('Neumonía · Oxitetraciclina (10 ml)'), findsNothing);
    expect(find.text('Derivado'), findsOneWidget);
    expect(find.text('AR-020'), findsOneWidget);
  });

  testWidgets('Desde Sanidad hay que elegir un animal', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => abrirRegistroTratamiento(context), child: const Text('abrir')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar tratamiento'));
    await tester.pumpAndSettle();

    expect(find.text('Elegí un solo animal'), findsOneWidget);
  });

  testWidgets('Un rol sin escritura en Sanidad no ve los botones, ni en el detalle', (tester) async {
    SesionActual.instancia.guardar(
      token: 't',
      nombreRancho: 'R',
      nombreUsuario: 'Beto',
      rol: 'EncargadoCorrales',
      permisos: {'Sanidad': 'Lectura'},
    );
    final servidor = _Servidor()..tratamientos.add(_tratamiento('Neumonía', fechaDeHoy(), 5));

    await http.runWithClient(() async {
      await mostrarFicha(tester);
      expect(find.text('Registrar tratamiento'), findsNothing);
      expect(find.text('Tratamientos'), findsOneWidget);

      await tester.tap(find.text('Neumonía · Oxitetraciclina (10 ml)'));
      await tester.pumpAndSettle();
    }, () => MockClient(servidor.responder));

    expect(find.text('Registrar seguimiento'), findsNothing);
    expect(find.text('Finalizar tratamiento'), findsNothing);
  });
}
