import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/main.dart';

void main() {
  // Simula entrar a la app por una dirección puntual (como un link externo).
  Future<void> abrirEn(WidgetTester tester, String ruta) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = ruta;
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(const GanaderiaProApp());
    await tester.pumpAndSettle();
  }

  bool sePuedeVolver(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator)).canPop();

  testWidgets('La app arranca en la pantalla de inicio de sesion', (WidgetTester tester) async {
    await tester.pumpWidget(const GanaderiaProApp());

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('El login no deja "volver" al Inicio sin haber iniciado sesion', (tester) async {
    await tester.pumpWidget(const GanaderiaProApp());
    await tester.pumpAndSettle();

    expect(sePuedeVolver(tester), isFalse);
  });

  testWidgets('Sin sesion, una pantalla protegida lleva al login', (tester) async {
    await abrirEn(tester, '/ganado');

    expect(find.text('Ingresar'), findsOneWidget);
    expect(sePuedeVolver(tester), isFalse);
  });

  testWidgets('El plan elegido en el sitio publico llega preseleccionado al registro', (tester) async {
    await abrirEn(tester, '/registro?plan=Intermedio');

    expect(find.text('Intermedio'), findsOneWidget);
    expect(sePuedeVolver(tester), isFalse);
  });
}
