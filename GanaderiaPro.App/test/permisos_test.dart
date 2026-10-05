import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/features/corrales/corrales_screen.dart';
import 'package:ganaderia_pro_app/features/ganado/listado_animales_screen.dart';
import 'package:ganaderia_pro_app/features/sanidad/sanidad_screen.dart';
import 'package:ganaderia_pro_app/features/shell/app_shell.dart';
import 'package:ganaderia_pro_app/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// HU-34: permisos tal como los manda el servidor para cada rol (sección 5).
const _veterinario = {
  'Ganado': 'Lectura',
  'Pesaje': 'Escritura',
  'Corrales': 'Lectura',
  'Sanidad': 'Escritura',
  'Colaboradores': 'Ninguno',
  'Tablero': 'Lectura',
};
const _encargadoCorrales = {
  'Ganado': 'Lectura',
  'Pesaje': 'Escritura',
  'Corrales': 'Escritura',
  'Sanidad': 'Lectura',
  'Colaboradores': 'Ninguno',
  'Tablero': 'Lectura',
};

final _animal = {
  'id': 'a1',
  'arete': 'AR-001',
  'sexo': 'Hembra',
  'raza': 'Nelore',
  'peso': 300,
  'estado': 'Activo',
  'fechaRegistro': '2026-10-01T12:00:00Z',
  'fechaNacimiento': '2024-01-10',
  'categoria': 'Vaquillona',
};

// Responde lo mínimo que piden las pantallas para dibujarse.
http.Response _servidor(http.Request request) {
  final ruta = request.url.path;
  if (ruta.endsWith('/animales/resumen')) {
    return http.Response(jsonEncode({'activos': 1, 'hembrasActivas': 1, 'machosActivos': 0, 'vendidos': 0, 'fallecidos': 0}), 200);
  }
  if (ruta.endsWith('/sanidad/resumen')) {
    return http.Response(jsonEncode({'vacunados': 0, 'pendientes': 0, 'vencidas': 0}), 200);
  }
  if (ruta.endsWith('/animales')) return http.Response(jsonEncode([_animal]), 200);
  if (ruta.endsWith('/corrales')) {
    return http.Response(
      jsonEncode([
        {'id': 'c1', 'nombre': 'Corral Norte', 'capacidad': 10, 'activo': true, 'animalesActivos': 0, 'porcentajeOcupacion': 0},
      ]),
      200,
    );
  }
  return http.Response('[]', 200);
}

void main() {
  tearDown(SesionActual.instancia.cerrar);

  void entrarComo(String rol, Map<String, String> permisos) =>
      SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Usuario', rol: rol, permisos: permisos);

  Future<void> abrir(WidgetTester tester, Widget pantalla) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: pantalla));
      await tester.pumpAndSettle();
    }, () => MockClient((r) async => _servidor(r)));
  }

  test('Ver y editar dependen del nivel de cada módulo', () {
    entrarComo('Veterinario', _veterinario);
    final s = SesionActual.instancia;

    expect((s.puedeVer('Corrales'), s.puedeEditar('Corrales')), (true, false));
    expect((s.puedeVer('Sanidad'), s.puedeEditar('Sanidad')), (true, true));
    expect(s.puedeVer('Colaboradores'), isFalse);
  });

  testWidgets('El menú del veterinario no tiene Colaboradores', (tester) async {
    entrarComo('Veterinario', _veterinario);
    await abrir(tester, const AppShell(seccionActiva: '/', body: SizedBox()));

    expect(find.text('Animales'), findsOneWidget);
    expect(find.text('Sanidad'), findsOneWidget);
    expect(find.text('Colaboradores'), findsNothing);
  });

  testWidgets('Con solo lectura en Animales: sin botones y con "Solo consulta"', (tester) async {
    entrarComo('Veterinario', _veterinario);
    await abrir(tester, const ListadoAnimalesScreen());

    expect(find.text('Solo consulta'), findsOneWidget);
    expect(find.text('Agregar animales'), findsNothing);
    expect(find.byTooltip('Editar'), findsNothing);
    expect(find.byTooltip('Eliminar'), findsNothing);
    expect(find.byTooltip('Registrar baja'), findsNothing);
    expect(find.text('AR-001'), findsOneWidget);
  });

  testWidgets('El propietario ve todos los botones y sin "Solo consulta"', (tester) async {
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');
    await abrir(tester, const ListadoAnimalesScreen());

    expect(find.text('Solo consulta'), findsNothing);
    expect(find.text('Agregar animales'), findsOneWidget);
    expect(find.byTooltip('Editar'), findsOneWidget);
    expect(find.byTooltip('Registrar baja'), findsOneWidget);
  });

  testWidgets('El encargado de corrales puede crear corrales; el veterinario solo los mira', (tester) async {
    entrarComo('EncargadoCorrales', _encargadoCorrales);
    await abrir(tester, const CorralesScreen());
    expect(find.text('Nuevo corral'), findsOneWidget);
    expect(find.byTooltip('Editar corral'), findsOneWidget);

    entrarComo('Veterinario', _veterinario);
    await abrir(tester, const CorralesScreen());
    expect(find.text('Nuevo corral'), findsNothing);
    expect(find.byTooltip('Editar corral'), findsNothing);
    expect(find.text('Solo consulta'), findsOneWidget);
  });

  testWidgets('El veterinario registra vacunas; el encargado de corrales no', (tester) async {
    entrarComo('Veterinario', _veterinario);
    await abrir(tester, const SanidadScreen());
    expect(find.text('Registrar vacunación'), findsOneWidget);

    entrarComo('EncargadoCorrales', _encargadoCorrales);
    await abrir(tester, const SanidadScreen());
    expect(find.text('Registrar vacunación'), findsNothing);
    expect(find.text('Solo consulta'), findsOneWidget);
  });

  testWidgets('Entrar por dirección a un módulo sin permiso muestra el aviso', (tester) async {
    entrarComo('Veterinario', _veterinario);
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/colaboradores';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await http.runWithClient(() async {
      await tester.pumpWidget(const GanaderiaProApp());
      await tester.pumpAndSettle();
    }, () => MockClient((r) async => _servidor(r)));

    expect(find.text('No tienes permiso para acceder a este módulo'), findsOneWidget);
    expect(find.text('Ir al tablero'), findsOneWidget);
  });
}
