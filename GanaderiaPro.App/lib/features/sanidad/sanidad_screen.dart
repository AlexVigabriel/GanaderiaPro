import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/sanidad.dart';
import '../../core/widgets/componentes.dart';
import '../shell/app_shell.dart';
import 'registro_vacunacion_dialog.dart';
import 'vacunaciones_widgets.dart';

// HU-26: módulo Sanidad. Registra vacunaciones (una o varias a la vez) y
// muestra las últimas aplicadas en el rancho.
class SanidadScreen extends StatefulWidget {
  const SanidadScreen({super.key});

  @override
  State<SanidadScreen> createState() => _SanidadScreenState();
}

class _SanidadScreenState extends State<SanidadScreen> {
  final _api = ApiClient();
  late Future<List<Vacunacion>> _recientes = _api.listarVacunaciones();

  void _recargar() => setState(() {
    _recientes = _api.listarVacunaciones();
  });

  void _avisar(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  Future<void> _registrar() async {
    final guardadas = await abrirRegistroVacunacion(context);
    if (guardadas == null || !mounted) return;
    _avisar(guardadas == 1 ? 'Vacunación registrada.' : 'Se vacunaron $guardadas animales.');
    _recargar();
  }

  Future<void> _editar(Vacunacion v) async {
    final guardadas = await abrirRegistroVacunacion(context, editar: v);
    if (guardadas == null || !mounted) return;
    _avisar('Vacunación corregida.');
    _recargar();
  }

  Future<void> _eliminar(Vacunacion v) async {
    if (!await eliminarVacunacion(context, v) || !mounted) return;
    _avisar('Vacunación eliminada.');
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AppShell(
      seccionActiva: '/sanidad',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoPantalla(
              titulo: 'Sanidad',
              subtitulo: 'Registrá vacunaciones y seguí el calendario sanitario del rancho.',
              acciones: [
                FilledButton.icon(
                  onPressed: _registrar,
                  icon: const Icon(Icons.vaccines_outlined),
                  label: const Text('Registrar vacunación'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Últimas vacunaciones', style: tema.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Vacunacion>>(
                      future: _recientes,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Column(
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                snapshot.error is ApiException
                                    ? (snapshot.error as ApiException).mensaje
                                    : 'No se pudo conectar con el servidor.',
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(onPressed: _recargar, child: const Text('Reintentar')),
                            ],
                          );
                        }
                        final vacunaciones = snapshot.data!;
                        if (vacunaciones.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(Icons.vaccines_outlined, size: 40, color: tema.colorScheme.onSurfaceVariant),
                                const SizedBox(height: 12),
                                Text('Todavía no hay vacunaciones registradas', style: tema.textTheme.titleMedium),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final v in vacunaciones)
                              FilaVacunacion(
                                vacunacion: v,
                                mostrarAnimal: true,
                                onEditar: () => _editar(v),
                                onEliminar: () => _eliminar(v),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
