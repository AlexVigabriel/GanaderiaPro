import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/main.dart';

void main() {
  testWidgets('La app arranca y muestra el menu lateral', (WidgetTester tester) async {
    await tester.pumpWidget(const GanaderiaProApp());

    expect(find.text('Inicio'), findsNothing);

    final scaffoldFinder = find.byType(Scaffold);
    expect(scaffoldFinder, findsOneWidget);
  });
}
