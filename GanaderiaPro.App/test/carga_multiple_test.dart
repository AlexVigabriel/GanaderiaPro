import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/core/app_theme.dart';
import 'package:ganaderia_pro_app/features/ganado/carga_multiple_dialog.dart';

void main() {
  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.claro, home: const Scaffold(body: CargaMultipleAnimales())),
    );
  }

  // Cada fila tiene tres campos de texto, en este orden: arete, nombre y peso al nacer.
  Finder campo(int fila, int columna) => find.byType(TextField).at(fila * 3 + columna);

  testWidgets('Sin sexo ni raza, la carga muestra los errores de validacion', (tester) async {
    await abrir(tester);
    await tester.enterText(campo(0, 0), 'AR-001');
    await tester.pump();

    await tester.tap(find.text('Cargar 1 animal'));
    await tester.pump();

    expect(find.text('Revisá la carga'), findsOneWidget);
    expect(find.text('Elegí el sexo'), findsOneWidget);
    expect(find.text('La raza es obligatoria'), findsOneWidget);
  });

  testWidgets('Detecta aretes repetidos dentro de la tabla', (tester) async {
    await abrir(tester);
    await tester.enterText(campo(0, 0), 'AR-001');
    await tester.tap(find.text('Agregar fila'));
    await tester.pump();
    await tester.enterText(campo(1, 0), 'AR-001');
    await tester.pump();

    await tester.tap(find.text('Cargar 2 animales'));
    await tester.pump();

    expect(find.text('Repetido en la tabla'), findsNWidgets(2));
  });

  testWidgets('Duplicar copia la fila sin el arete y eliminar la quita', (tester) async {
    await abrir(tester);
    await tester.enterText(campo(0, 0), 'AR-001');
    await tester.enterText(campo(0, 1), 'Rita');
    await tester.pump();

    await tester.tap(find.byTooltip('Duplicar fila'));
    await tester.pump();

    expect(find.text('Rita'), findsNWidgets(2));
    expect(tester.widget<TextField>(campo(1, 0)).controller!.text, isEmpty);

    await tester.tap(find.byTooltip('Eliminar fila').at(1));
    await tester.pump();

    expect(find.text('Rita'), findsOneWidget);
  });

  testWidgets('El lapiz abre el detalle de la fila', (tester) async {
    await abrir(tester);
    expect(find.text('Peso actual (kg)'), findsNothing);

    await tester.tap(find.byTooltip('Abrir detalle'));
    await tester.pump();

    expect(find.text('Peso actual (kg)'), findsOneWidget);
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Observaciones'), findsOneWidget);
  });
}
