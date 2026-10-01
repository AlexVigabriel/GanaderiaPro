import 'package:flutter_test/flutter_test.dart';
import 'package:ganaderia_pro_app/main.dart';

void main() {
  testWidgets('La app arranca en la pantalla de inicio de sesion', (WidgetTester tester) async {
    await tester.pumpWidget(const GanaderiaProApp());

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('¿No tenés cuenta? Crear cuenta'), findsOneWidget);
  });
}
