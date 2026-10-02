import 'package:flutter/material.dart';

import '../../core/sesion_actual.dart';
import '../../core/widgets/componentes.dart';
import 'app_shell.dart';

// Los indicadores del tablero son HU-12/HU-13 (Sprint 3). Mientras tanto,
// la pantalla da la bienvenida y lleva a los módulos que ya existen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nombre = SesionActual.instancia.nombreUsuario?.split(' ').first;

    return AppShell(
      seccionActiva: '/',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EncabezadoPantalla(
              titulo: nombre == null ? 'Tablero' : 'Hola, $nombre',
              subtitulo: 'Resumen de tu rancho y accesos rápidos.',
            ),
            const SizedBox(height: 28),
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/ganado', (r) => false),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: tema.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.pets_outlined, color: tema.colorScheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Animales', style: tema.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Cargá tu ganado y consultá la ficha de cada animal.',
                              style: tema.textTheme.bodyMedium?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward, color: tema.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
