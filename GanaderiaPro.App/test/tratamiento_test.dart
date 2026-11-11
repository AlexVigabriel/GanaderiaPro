import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
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

Map<String, dynamic> _tratamiento(String motivo, DateTime inicio, int dias, {required bool enCurso}) => {
  'id': 't-$motivo',
  'motivo': motivo,
  'medicamento': 'Oxitetraciclina',
  'dosis': '10 ml',
  'fechaInicio': _iso(inicio),
  'duracionDias': dias,
  'fechaFin': _iso(inicio.add(Duration(days: dias - 1))),
  'enCurso': enCurso,
  'observacion': null,
  'veterinario': 'Dra. Rojas',
};

// Simula el servidor: vacunaciones vacías y tratamientos en memoria.
class _Servidor {
  final tratamientos = <Map<String, dynamic>>[];
  Map<String, dynamic>? enviado;

  Future<http.Response> responder(http.Request request) async {
    if (request.url.path.endsWith('/tratamientos')) {
      if (request.method == 'POST') {
        enviado = jsonDecode(request.body) as Map<String, dynamic>;
        final inicio = DateTime.parse(enviado!['fechaInicio'] as String);
        tratamientos.insert(
          0,
          _tratamiento(enviado!['motivo'] as String, inicio, enviado!['duracionDias'] as int, enCurso: true),
        );
        return http.Response(jsonEncode(tratamientos.first), 200);
      }
      return http.Response(jsonEncode(tratamientos), 200);
    }
    return http.Response('[]', 200);
  }
}

void main() {
  setUp(() => SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana'));
  tearDown(SesionActual.instancia.cerrar);

  Future<void> mostrarFicha(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(body: SingleChildScrollView(child: TarjetaHistorialSanitario(animal: _animal()))),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Registra un tratamiento desde la ficha y aparece aparte de las vacunas, «En curso»', (tester) async {
    final servidor = _Servidor();

    await http.runWithClient(() async {
      await mostrarFicha(tester);
      expect(find.text('Este animal no tiene tratamientos registrados.'), findsOneWidget);

      await tester.tap(find.text('Registrar tratamiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar tratamiento'));
      await tester.pumpAndSettle();
      expect(find.text('El motivo es obligatorio'), findsOneWidget);
      expect(find.text('De 1 a 365 días'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Motivo o diagnóstico'), 'Neumonía');
      await tester.enterText(find.widgetWithText(TextField, 'Medicamento'), 'Oxitetraciclina');
      await tester.enterText(find.widgetWithText(TextField, 'Dosis'), '10 ml');
      await tester.enterText(find.widgetWithText(TextField, 'Duración'), '5');
      await tester.tap(find.text('Guardar tratamiento'));
      await tester.pumpAndSettle();
    }, () => MockClient(servidor.responder));

    expect(servidor.enviado, {
      'motivo': 'Neumonía',
      'medicamento': 'Oxitetraciclina',
      'dosis': '10 ml',
      'fechaInicio': _iso(fechaDeHoy()),
      'duracionDias': 5,
      'observacion': null,
    });
    expect(find.text('Vacunaciones'), findsOneWidget);
    expect(find.text('Tratamientos'), findsOneWidget);
    expect(find.text('Neumonía · Oxitetraciclina (10 ml)'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
  });

  testWidgets('Un tratamiento terminado figura como «Finalizado»', (tester) async {
    final servidor = _Servidor()
      ..tratamientos.add(_tratamiento('Diarrea', DateTime(2026, 9, 1), 3, enCurso: false));

    await http.runWithClient(() async {
      await mostrarFicha(tester);
    }, () => MockClient(servidor.responder));

    expect(find.text('Finalizado'), findsOneWidget);
    expect(find.textContaining('01/09/2026 al 03/09/2026 · 3 días · Dra. Rojas'), findsOneWidget);
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

  testWidgets('Un rol sin escritura en Sanidad no ve el botón', (tester) async {
    SesionActual.instancia.guardar(
      token: 't',
      nombreRancho: 'R',
      nombreUsuario: 'Beto',
      rol: 'EncargadoCorrales',
      permisos: {'Sanidad': 'Lectura'},
    );

    await http.runWithClient(() async {
      await mostrarFicha(tester);
    }, () => MockClient(_Servidor().responder));

    expect(find.text('Registrar tratamiento'), findsNothing);
    expect(find.text('Tratamientos'), findsOneWidget);
  });
}
