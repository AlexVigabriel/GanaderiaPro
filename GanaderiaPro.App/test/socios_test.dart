import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/features/shell/app_shell.dart';
import 'package:ganaderia_pro_app/features/socios/socios_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// HU-29 y HU-30: registrar socios y ver su listado.
Map<String, dynamic> _socio(String nombre, String estado, {String? acceso, String? vence}) => {
  'id': nombre,
  'nombre': nombre,
  'email': '${nombre.toLowerCase()}@x.com',
  'rol': 'Socio',
  'estado': estado,
  'ultimoAcceso': acceso,
  'invitacionVence': vence,
};

void main() {
  tearDown(SesionActual.instancia.cerrar);

  void pantallaGrande(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('El menú muestra Socios solo al propietario', (tester) async {
    pantallaGrande(tester);
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Vet', rol: 'Veterinario');
    await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const AppShell(seccionActiva: '/', body: SizedBox())));
    expect(find.text('Socios'), findsNothing);

    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana', rol: 'Propietario');
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.claro, home: const AppShell(seccionActiva: '/ganado', body: SizedBox())),
    );
    expect(find.text('Socios'), findsOneWidget);
  });

  testWidgets('La tabla muestra estado y último acceso o «Nunca»', (tester) async {
    pantallaGrande(tester);
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const SociosScreen()));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (!request.url.path.endsWith('/socios')) return http.Response('{}', 404);
      return http.Response(
        jsonEncode([
          _socio('Laura', 'Activo', acceso: '2026-10-05T13:07:00Z'),
          _socio('Pedro', 'Pendiente', vence: '2099-10-12T12:00:00Z'),
        ]),
        200,
      );
    }));

    expect(find.text('Laura'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Nunca'), findsOneWidget);
    expect(find.textContaining('05/10/2026'), findsOneWidget);
    // Solo el pendiente tiene el botón de nuevo enlace.
    expect(find.byTooltip('Generar nuevo enlace'), findsOneWidget);
  });

  testWidgets('Registrar un socio envía nombre y correo y muestra el enlace', (tester) async {
    pantallaGrande(tester);
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');
    Map<String, dynamic>? enviado;

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const SociosScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar al primero'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Ej. Pedro Mamani'), 'Pedro Mamani');
      await tester.enterText(find.widgetWithText(TextField, 'pedro@correo.com'), 'pedro@correo.com');
      await tester.tap(find.text('Crear invitación'));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/socios')) {
        enviado = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'colaborador': _socio('Pedro Mamani', 'Pendiente'),
            'codigo': 'codigo-secreto',
            'vence': '2099-10-12T12:00:00Z',
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/socios')) return http.Response('[]', 200);
      return http.Response('{}', 404);
    }));

    expect(enviado, {'nombre': 'Pedro Mamani', 'email': 'pedro@correo.com'});
    expect(find.text('Enlace para Pedro Mamani'), findsOneWidget);
  });

  testWidgets('Si el plan no permite más socios, muestra el mensaje del servidor', (tester) async {
    pantallaGrande(tester);
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const SociosScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar al primero'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Ej. Pedro Mamani'), 'Pedro');
      await tester.enterText(find.widgetWithText(TextField, 'pedro@correo.com'), 'pedro@correo.com');
      await tester.tap(find.text('Crear invitación'));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'mensaje': 'Llegaste al límite de 2 socios de tu plan Básico.'}), 400);
      }
      if (request.url.path.endsWith('/socios')) return http.Response('[]', 200);
      return http.Response('{}', 404);
    }));

    expect(find.text('Llegaste al límite de 2 socios de tu plan Básico.'), findsOneWidget);
  });
}
