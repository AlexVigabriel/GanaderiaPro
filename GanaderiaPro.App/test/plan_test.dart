import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/plan.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/core/widgets/plan_widgets.dart';
import 'package:ganaderia_pro_app/features/shell/home_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _recurso(String recurso, int usados, int? limite) {
  final porcentaje = limite == null ? null : (usados * 100 / limite).round();
  return {
    'recurso': recurso,
    'usados': usados,
    'limite': limite,
    'porcentaje': porcentaje,
    'cercaDelLimite': porcentaje != null && porcentaje >= 90,
    'lleno': limite != null && usados >= limite,
  };
}

UsoPlan _uso({int animales = 10, int colaboradores = 1, String plan = 'Básico', String? siguiente = 'Intermedio', int? limite = 100}) =>
    UsoPlan.fromJson({
      'plan': 'Basico',
      'nombrePlan': plan,
      'planSiguiente': siguiente,
      'recursos': [
        _recurso('Animales', animales, limite),
        _recurso('Colaboradores', colaboradores, limite == null ? null : 3),
        _recurso('Socios', 0, limite == null ? null : 2),
      ],
    });

void main() {
  tearDown(SesionActual.instancia.cerrar);

  group('Aviso del límite del plan (HU-58)', () {
    test('sin aviso por debajo del 90 %', () => expect(avisoDeLimite(_uso(animales: 89), 'Animales'), isNull));

    test('al 90 % avisa el uso y sugiere el plan siguiente', () {
      expect(
        avisoDeLimite(_uso(animales: 92), 'Animales'),
        'Usaste 92 de 100 animales activos de tu plan Básico. Para sumar más, pasate al plan Intermedio.',
      );
    });

    test('lleno avisa que llegó al límite', () {
      expect(avisoDeLimite(_uso(colaboradores: 3), 'Colaboradores'), startsWith('Llegaste al límite de tu plan Básico: 3 de 3 colaboradores.'));
    });

    test('el plan Superior no avisa: no tiene límite', () {
      expect(avisoDeLimite(_uso(animales: 900, plan: 'Superior', siguiente: null, limite: null), 'Animales'), isNull);
    });
  });

  testWidgets('La tarjeta del plan muestra el uso de cada recurso', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: Scaffold(body: TarjetaPlan(uso: _uso(animales: 92)))));

    expect(find.text('Tu plan Básico'), findsOneWidget);
    expect(find.text('92 / 100'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
  });

  testWidgets('El tablero del propietario muestra "Tu plan" y el aviso del 90 %', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');
    final respuesta = jsonEncode({
      'plan': 'Basico',
      'nombrePlan': 'Básico',
      'planSiguiente': 'Intermedio',
      'recursos': [_recurso('Animales', 95, 100), _recurso('Colaboradores', 1, 3), _recurso('Socios', 0, 2)],
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const HomeScreen()));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async => http.Response(respuesta, 200)));

    expect(find.text('Tu plan Básico'), findsOneWidget);
    expect(find.textContaining('Usaste 95 de 100 animales activos'), findsOneWidget);
  });

  testWidgets('Otro rol no ve el plan en el tablero', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SesionActual.instancia.guardar(
      token: 't',
      nombreRancho: 'R',
      nombreUsuario: 'Vet',
      rol: 'Veterinario',
      permisos: const {'Ganado': 'Lectura', 'Tablero': 'Lectura', 'Configuracion': 'Ninguno'},
    );
    var pidioElPlan = false;

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const HomeScreen()));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      pidioElPlan = true;
      return http.Response('{}', 403);
    }));

    expect(pidioElPlan, isFalse);
    expect(find.textContaining('Tu plan'), findsNothing);
  });
}
