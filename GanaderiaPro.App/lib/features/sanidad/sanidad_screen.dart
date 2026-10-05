import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../core/sanidad.dart';
import '../../core/validaciones_animal.dart';
import '../../core/widgets/componentes.dart';
import '../shell/app_shell.dart';
import 'registro_vacunacion_dialog.dart';
import 'vacunaciones_widgets.dart';

// Módulo Sanidad: indicadores y pendientes (HU-27), registro de
// vacunaciones de uno o varios animales y últimas aplicadas (HU-26).
class SanidadScreen extends StatefulWidget {
  const SanidadScreen({super.key});

  @override
  State<SanidadScreen> createState() => _SanidadScreenState();
}

class _SanidadScreenState extends State<SanidadScreen> {
  final _api = ApiClient();
  late Future<List<Vacunacion>> _recientes = _api.listarVacunaciones();
  late Future<ResumenSanidad> _resumen = _api.obtenerResumenSanidad();
  late Future<List<Pendiente>> _pendientes = _api.listarPendientes();

  void _recargar() => setState(() {
    _recientes = _api.listarVacunaciones();
    _resumen = _api.obtenerResumenSanidad();
    _pendientes = _api.listarPendientes();
  });

  // Aplica una dosis pendiente: el formulario se abre con el animal y la
  // vacuna ya elegidos. Al registrarla, la pendiente queda cumplida.
  Future<void> _aplicar(Pendiente p) async {
    try {
      final animal = await _api.obtenerAnimal(p.animalId);
      if (!mounted) return;
      final guardadas = await abrirRegistroVacunacion(context, animal: animal, vacunaInicial: p.vacunaId);
      if (guardadas == null || !mounted) return;
      _avisar('Dosis de ${p.vacuna} aplicada a ${p.arete}.');
      _recargar();
    } on ApiException catch (e) {
      if (mounted) _avisar(e.mensaje);
    } catch (_) {
      if (mounted) _avisar('No se pudo conectar con el servidor.');
    }
  }

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
            _indicadores(),
            const SizedBox(height: 24),
            _tarjetaPendientes(tema),
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

  // HU-27 / RN-09: Vacunados, Pendientes y Vencidas. Sin datos, todo en 0.
  Widget _indicadores() => FutureBuilder<ResumenSanidad>(
    future: _resumen,
    builder: (context, snapshot) {
      final r = snapshot.data;
      final tarjetas = [
        TarjetaIndicador(etiqueta: 'Vacunados', valor: r?.vacunados, icono: Icons.verified_outlined),
        TarjetaIndicador(etiqueta: 'Pendientes', valor: r?.pendientes, icono: Icons.event_outlined),
        TarjetaIndicador(etiqueta: 'Vencidas', valor: r?.vencidas, icono: Icons.event_busy_outlined),
      ];
      return LayoutBuilder(
        builder: (context, restricciones) {
          const espacio = 16.0;
          final columnas = restricciones.maxWidth >= 640 ? 3 : 1;
          final ancho = (restricciones.maxWidth - espacio * (columnas - 1)) / columnas;
          return Wrap(
            spacing: espacio,
            runSpacing: espacio,
            children: [for (final t in tarjetas) SizedBox(width: ancho, child: t)],
          );
        },
      );
    },
  );

  // HU-27: pendientes ordenadas por fecha de próxima dosis.
  Widget _tarjetaPendientes(ThemeData tema) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vacunaciones pendientes', style: tema.textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<List<Pendiente>>(
            future: _pendientes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Text(
                  'No se pudieron cargar las vacunaciones pendientes.',
                  style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error),
                );
              }
              final pendientes = snapshot.data!;
              if (pendientes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: tema.colorScheme.primary),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('No hay dosis pendientes.')),
                    ],
                  ),
                );
              }
              return Column(
                children: [for (final p in pendientes) _FilaPendiente(pendiente: p, onAplicar: () => _aplicar(p))],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _FilaPendiente extends StatelessWidget {
  const _FilaPendiente({required this.pendiente, required this.onAplicar});

  final Pendiente pendiente;
  final VoidCallback onAplicar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final p = pendiente;
    final color = p.vencida ? tema.colorScheme.error : tema.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: tema.colorScheme.outlineVariant))),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(p.vencida ? Icons.event_busy_outlined : Icons.event_outlined, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.animal} — ${p.vacuna}', style: tema.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Próxima dosis ${formatearFecha(p.fechaProximaDosis)} · última aplicación ${formatearFecha(p.ultimaAplicacion)}',
                  style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              describirVencimiento(p.fechaProximaDosis, fechaDeHoy()),
              style: tema.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onAplicar, child: const Text('Aplicar')),
        ],
      ),
    );
  }
}
