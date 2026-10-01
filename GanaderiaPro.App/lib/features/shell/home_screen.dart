import 'package:flutter/material.dart';

import 'app_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShell(
      seccionActiva: '/',
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Dashboard con indicadores (HU-12/HU-13): fuera del alcance de '
          'HU-14/HU-15, que solo cubren la navegación.',
        ),
      ),
    );
  }
}
