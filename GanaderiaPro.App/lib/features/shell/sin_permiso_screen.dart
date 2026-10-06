import 'package:flutter/material.dart';

import 'app_shell.dart';

// HU-34: si alguien entra a un módulo por dirección directa sin permiso. El
// servidor igual responde 403: esta pantalla es para que lo entienda.
class SinPermisoScreen extends StatelessWidget {
  const SinPermisoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AppShell(
      seccionActiva: '',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: tema.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No tienes permiso para acceder a este módulo',
                textAlign: TextAlign.center,
                style: tema.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Tu rol no incluye este módulo. Si lo necesitás, pedile al propietario del rancho que cambie tu rol.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
                icon: const Icon(Icons.space_dashboard_outlined),
                label: const Text('Ir al tablero'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
