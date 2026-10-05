import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/corral.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/core/widgets/componentes.dart';
import 'package:ganaderia_pro_app/features/corrales/cambiar_corral_dialog.dart';
import 'package:ganaderia_pro_app/features/corrales/corral_dialog.dart';
import 'package:ganaderia_pro_app/features/corrales/corrales_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _corral(String id, String nombre, int capacidad, int animales, {bool activo = true}) => {
  'id': id,
  'nombre': nombre,
  'capacidad': capacidad,
  'activo': activo,
  'animalesActivos': animales,
  'porcentajeOcupacion': (animales * 100 / capacidad).round(),
};

void main() {
  setUp(() => SesionActual.instancia.guardar(token: 't', nombreRancho: 'Estancia', nombreUsuario: 'Ana Vega'));
  tearDown(SesionActual.instancia.cerrar);

  group('Reglas del corral (HU-23)', () {
    test('nombre obligatorio', () => expect(validarNombreCorral('  '), 'El nombre es obligatorio'));
    test('capacidad entera de 1 o más', () {
      expect(validarCapacidad('0'), 'Debe estar entre 1 y 10000');
      expect(validarCapacidad(''), 'Ingresá un número entero');
      expect(validarCapacidad('25'), isNull);
    });
    test('RN-07: no más animales que la capacidad', () {
      expect(validarOcupacion(3, 2), 'La capacidad es 2: quedan 2 lugares y elegiste 3 animales');
      expect(validarOcupacion(2, 2), isNull);
    });
  });

  test('El resumen suma solo corrales activos y pondera la ocupación', () {
    final corrales = [
      Corral.fromJson(_corral('1', 'Norte', 25, 18)),
      Corral.fromJson(_corral('2', 'Sur', 25, 7)),
      Corral.fromJson(_corral('3', 'Viejo', 10, 0, activo: false)),
    ];

    final r = ResumenCorrales.de(corrales);

    expect((r.corrales, r.animales, r.ocupacionPromedio), (2, 25, 50));
  });

  test('El color de la ocupación cambia a ámbar desde 80 % y a rojo lleno', () {
    final colores = AppTheme.claro.colorScheme;
    expect(colorOcupacion(72, colores), colores.primary);
    expect(colorOcupacion(80, colores), isNot(colores.primary));
    expect(colorOcupacion(100, colores), colores.error);
  });

  Future<void> abrir(WidgetTester tester, List<Map<String, dynamic>> corrales) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const CorralesScreen()));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async => http.Response(jsonEncode(corrales), 200)));
  }

  testWidgets('Sin corrales muestra el estado vacío con "Crear el primero"', (tester) async {
    await abrir(tester, []);

    expect(find.text('No hay corrales'), findsOneWidget);
    expect(find.text('Crear el primero'), findsOneWidget);
  });

  testWidgets('Cada tarjeta muestra animales / capacidad y la ocupación', (tester) async {
    await abrir(tester, [_corral('1', 'Corral Norte', 25, 18)]);

    expect(find.text('Corral Norte'), findsOneWidget);
    expect(find.text('/ 25 animales'), findsOneWidget);
    expect(find.text('72 %'), findsOneWidget);
    expect(find.text('7 lugares libres'), findsOneWidget);
  });

  testWidgets('RN-08: un corral con animales no se puede desactivar', (tester) async {
    await abrir(tester, [_corral('1', 'Corral Norte', 25, 18), _corral('2', 'Corral Vacío', 10, 0)]);

    final botones = tester.widgetList<BotonAccion>(find.byType(BotonAccion)).where((b) => b.icono == Icons.visibility_off_outlined).toList();

    expect(botones[0].onPressed, isNull);
    expect(botones[0].tooltip, 'Tiene 18 animales: reasignalos antes de desactivarlo');
    expect(botones[1].onPressed, isNotNull);
  });

  testWidgets('Al cambiar de corral, los llenos no se pueden elegir', (tester) async {
    final animal = Animal(
      id: 'a1',
      arete: 'AR-001',
      sexo: 'Hembra',
      raza: 'Nelore',
      peso: null,
      estado: 'Activo',
      fechaRegistro: DateTime(2026),
      corralId: '1',
      corral: 'Corral Norte',
    );
    String? enviado = 'sin enviar';
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => abrirCambioCorral(context, animal), child: const Text('abrir')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Corral actual · 18/25'), findsOneWidget);
      expect(find.text('Lleno (3/3)'), findsOneWidget);
      expect(
        tester.widget<RadioListTile<String?>>(find.widgetWithText(RadioListTile<String?>, 'Corral Chico')).enabled,
        isFalse,
      );

      await tester.tap(find.text('Sin corral'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.method == 'PUT') {
        enviado = (jsonDecode(request.body) as Map<String, dynamic>)['corralId'] as String?;
        return http.Response('', 204);
      }
      return http.Response(jsonEncode([_corral('1', 'Corral Norte', 25, 18), _corral('2', 'Corral Chico', 3, 3)]), 200);
    }));

    expect(enviado, isNull);
  });
}

