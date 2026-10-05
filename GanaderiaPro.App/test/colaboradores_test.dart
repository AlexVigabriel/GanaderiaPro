import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/colaborador.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/features/auth/aceptar_invitacion_screen.dart';
import 'package:ganaderia_pro_app/features/colaboradores/colaboradores_screen.dart';
import 'package:ganaderia_pro_app/features/shell/app_shell.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _colaborador(String nombre, String rol, String estado, {String? acceso, String? vence}) => {
  'id': nombre,
  'nombre': nombre,
  'email': '${nombre.toLowerCase()}@x.com',
  'rol': rol,
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

  group('HU-32', () {
    test('nombres de rol legibles', () {
      expect(nombreDeRol('EncargadoCorrales'), 'Encargado de corrales');
      expect(nombreDeRol('Propietario'), 'Propietario');
    });

    test('el enlace abre la pantalla de invitación con el código', () {
      final enlace = enlaceDeInvitacion('ab-c_1', base: Uri.parse('http://localhost:8090/#/colaboradores'));
      expect(enlace, 'http://localhost:8090/#/invitacion?codigo=ab-c_1');
    });

    test('último acceso o "Nunca"', () {
      expect(describirAcceso(null), 'Nunca');
      expect(describirAcceso(DateTime(2026, 10, 5, 9, 7)), '05/10/2026 09:07');
    });

    test('valida correo y contraseña nueva', () {
      expect(validarEmail('laura@correo.com'), isNull);
      expect(validarEmail('laura@'), 'Ingresá un correo válido');
      expect(validarContrasenaNueva('corta1'), 'Mínimo 8 caracteres, con letra y número');
      expect(validarContrasenaNueva('Clave1234'), isNull);
    });
  });

  testWidgets('El menú muestra Colaboradores solo al propietario', (tester) async {
    pantallaGrande(tester);
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Vet', rol: 'Veterinario');
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.claro, home: const AppShell(seccionActiva: '/', body: SizedBox())),
    );
    expect(find.text('Colaboradores'), findsNothing);

    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana', rol: 'Propietario');
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.claro, home: const AppShell(seccionActiva: '/ganado', body: SizedBox())),
    );
    expect(find.text('Colaboradores'), findsOneWidget);
  });

  testWidgets('La lista muestra rol, estado y el enlace para los pendientes', (tester) async {
    pantallaGrande(tester);
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const ColaboradoresScreen()));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async => http.Response(
      jsonEncode([
        _colaborador('Laura', 'Veterinario', 'Activo', acceso: '2026-10-05T13:07:00Z'),
        _colaborador('Pedro', 'EncargadoIngreso', 'Pendiente', vence: '2099-10-12T12:00:00Z'),
      ]),
      200,
    )));

    expect(find.text('Veterinario'), findsOneWidget);
    expect(find.text('Encargado de ingreso'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.textContaining('Invitación vence el 12/10/2099'), findsOneWidget);
    // Solo el pendiente tiene el botón de nuevo enlace.
    expect(find.byTooltip('Generar nuevo enlace'), findsOneWidget);
  });

  testWidgets('Invitar muestra el enlace para copiar', (tester) async {
    pantallaGrande(tester);
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');
    Map<String, dynamic>? enviado;

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const ColaboradoresScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invitar al primero'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Ej. Laura Rojas'), 'Laura Rojas');
      await tester.enterText(find.widgetWithText(TextField, 'laura@correo.com'), 'laura@correo.com');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Veterinario').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear invitación'));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.method == 'POST') {
        enviado = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'colaborador': _colaborador('Laura Rojas', 'Veterinario', 'Pendiente'),
            'codigo': 'codigo-secreto',
            'vence': '2099-10-12T12:00:00Z',
          }),
          200,
        );
      }
      return http.Response('[]', 200);
    }));

    expect(enviado, {'nombre': 'Laura Rojas', 'email': 'laura@correo.com', 'rol': 'Veterinario'});
    expect(find.text('Enlace para Laura Rojas'), findsOneWidget);
    expect(find.textContaining('/#/invitacion?codigo=codigo-secreto'), findsOneWidget);
    expect(find.text('Copiar enlace'), findsOneWidget);
  });

  testWidgets('Aceptar invitación: muestra el rancho y el rol y pide la contraseña', (tester) async {
    pantallaGrande(tester);
    Map<String, dynamic>? enviado;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: const AceptarInvitacionScreen(codigo: 'abc'),
          routes: {'/login': (_) => const Scaffold(body: Text('LOGIN'))},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Laura, te invitaron a La Esperanza como Veterinario.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Tu contraseña'), 'Clave1234');
      await tester.enterText(find.widgetWithText(TextFormField, 'Repetí tu contraseña'), 'Clave1234');
      await tester.tap(find.text('Aceptar invitación'));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.method == 'POST') {
        enviado = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('', 204);
      }
      return http.Response(
        jsonEncode({'rancho': 'La Esperanza', 'nombre': 'Laura', 'email': 'laura@x.com', 'rol': 'Veterinario', 'vence': '2099-01-01T00:00:00Z'}),
        200,
      );
    }));

    expect(enviado, {'contrasena': 'Clave1234', 'confirmarContrasena': 'Clave1234'});
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('Aceptar invitación con enlace vencido muestra el motivo', (tester) async {
    pantallaGrande(tester);

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.claro, home: const AceptarInvitacionScreen(codigo: 'viejo')));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async => http.Response(
      jsonEncode({'mensaje': 'El enlace no es válido o ya venció. Pedile al propietario del rancho uno nuevo.'}),
      400,
    )));

    expect(find.text('El enlace no es válido o ya venció. Pedile al propietario del rancho uno nuevo.'), findsOneWidget);
    expect(find.text('Ir a iniciar sesión'), findsOneWidget);
  });
}
