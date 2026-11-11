import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/animal.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/core/archivos.dart';
import 'package:ganaderia_pro_app/core/sesion_actual.dart';
import 'package:ganaderia_pro_app/features/ganado/excel_ganado.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Sin diálogos del sistema: guarda en memoria y "elige" un archivo fijo.
class _ArchivosFalsos extends ArchivosLocales {
  final guardados = <String, List<int>>{};

  // Los tipos se heredan de ArchivosLocales.
  @override
  elegirExcel() async => (nombre: 'mis_animales.xlsx', bytes: utf8.encode('xlsx'));

  @override
  guardar(nombre, bytes) async {
    guardados[nombre] = bytes;
    return true;
  }
}

// HU-43.1, HU-43.2 y HU-44: menú Excel del listado de ganado.
void main() {
  late _ArchivosFalsos archivos;

  setUp(() {
    archivos = _ArchivosFalsos();
    ArchivosLocales.instancia = archivos;
  });
  tearDown(() {
    ArchivosLocales.instancia = ArchivosLocales();
    SesionActual.instancia.cerrar();
  });

  Future<void> abrirMenu(WidgetTester tester, {required void Function() onImportado}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: Center(
            child: BotonExcel(
              filtros: () => (busqueda: 'AR', estado: 'Activo', sexo: 'Hembra', raza: null, categoria: null),
              onImportado: onImportado,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Excel'));
    await tester.pumpAndSettle();
  }

  test('Lee el resumen de la importación', () {
    final r = ResultadoImportacion.fromJson({
      'importadas': 8,
      'rechazadas': 1,
      'detalle': [
        {'fila': 5, 'arete': 'AR-001', 'motivo': 'Ya existe un animal con la identificación \'AR-001\' en este rancho.'},
      ],
    });
    expect((r.importadas, r.rechazadas, r.detalle.single.fila), (8, 1, 5));
    expect(r.detalle.single.motivo, startsWith('AR-001: Ya existe'));
  });

  testWidgets('Un socio solo ve Exportar', (tester) async {
    SesionActual.instancia.guardar(
      token: 't',
      nombreRancho: 'R',
      nombreUsuario: 'Socio',
      rol: 'Socio',
      permisos: const {'ExportarExcel': 'Escritura', 'ImportarExcel': 'Ninguno'},
    );
    await abrirMenu(tester, onImportado: () {});

    expect(find.text('Exportar a Excel'), findsOneWidget);
    expect(find.text('Importar desde Excel'), findsNothing);
    expect(find.text('Descargar plantilla'), findsNothing);
  });

  testWidgets('Exportar manda los filtros del listado y guarda el archivo del día', (tester) async {
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');
    Uri? pedida;

    await http.runWithClient(() async {
      await abrirMenu(tester, onImportado: () {});
      await tester.tap(find.text('Exportar a Excel'));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      pedida = request.url;
      return http.Response.bytes([9, 9], 200);
    }));

    expect(pedida!.path, endsWith('/api/animales/excel/exportar'));
    expect(pedida!.queryParameters, {'busqueda': 'AR', 'estado': 'Activo', 'sexo': 'Hembra'});
    expect(archivos.guardados.keys.single, matches(RegExp(r'^ganado_\d{4}-\d{2}-\d{2}\.xlsx$')));
  });

  testWidgets('Importar sube el archivo y muestra «N importadas, M rechazadas»', (tester) async {
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');
    var recargado = false;
    http.BaseRequest? subida;

    await http.runWithClient(() async {
      await abrirMenu(tester, onImportado: () => recargado = true);
      await tester.tap(find.text('Importar desde Excel'));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      subida = request;
      return http.Response(
        jsonEncode({
          'importadas': 2,
          'rechazadas': 1,
          'detalle': [
            {'fila': 3, 'arete': 'AR-021', 'motivo': 'Sexo inválido: usá M o H.'},
          ],
        }),
        200,
      );
    }));

    expect(subida!.url.path, endsWith('/api/animales/excel/importar'));
    expect(subida!.headers['content-type'], startsWith('multipart/form-data'));
    expect(find.text('2 importadas, 1 rechazadas'), findsOneWidget);
    expect(find.text('Fila 3'), findsOneWidget);
    expect(find.text('AR-021: Sexo inválido: usá M o H.'), findsOneWidget);
    expect(recargado, isTrue);
  });

  testWidgets('Si el archivo no coincide con la plantilla, muestra el motivo', (tester) async {
    SesionActual.instancia.guardar(token: 't', nombreRancho: 'R', nombreUsuario: 'Ana');
    const motivo = 'Las columnas del archivo no coinciden con la plantilla. Descargá la plantilla y usá sus mismos encabezados.';

    await http.runWithClient(() async {
      await abrirMenu(tester, onImportado: () {});
      await tester.tap(find.text('Importar desde Excel'));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async => http.Response(jsonEncode({'mensaje': motivo}), 400)));

    expect(find.text('No se pudo importar'), findsOneWidget);
    expect(find.text(motivo), findsOneWidget);
  });
}
