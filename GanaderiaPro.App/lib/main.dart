import 'package:flutter/material.dart';

import 'features/auth/login_screen.dart';
import 'features/ganado/listado_animales_screen.dart';
import 'features/shell/home_screen.dart';

void main() {
  runApp(const GanaderiaProApp());
}

class GanaderiaProApp extends StatelessWidget {
  const GanaderiaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GanaderíaPro',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/': (context) => const HomeScreen(),
        '/ganado': (context) => const ListadoAnimalesScreen(),
      },
    );
  }
}
