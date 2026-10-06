import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/permisos.dart';
import '../../core/plan.dart';
import '../../core/sesion_actual.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/plan_widgets.dart';
import 'app_shell.dart';

// Los indicadores del tablero son HU-12/HU-13 (Sprint 3). Mientras tanto,
// la pantalla da la bienvenida y lleva a los módulos que ya existen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // HU-58: "Tu plan" solo para el propietario (módulo Configuración).
  final Future<UsoPlan?>? _usoPlan = SesionActual.instancia.puedeVer(Modulos.configuracion)
      ? ApiClient().obtenerUsoPlan().then<UsoPlan?>((u) => u).catchError((_) => null)
      : null;

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
            if (_usoPlan != null) ...[
              const SizedBox(height: 16),
              FutureBuilder<UsoPlan?>(
                future: _usoPlan,
                builder: (context, snapshot) {
                  final uso = snapshot.data;
                  if (uso == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AvisoLimitePlan(uso: uso, recurso: 'Animales'),
                      AvisoLimitePlan(uso: uso, recurso: 'Colaboradores'),
                      TarjetaPlan(uso: uso),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
