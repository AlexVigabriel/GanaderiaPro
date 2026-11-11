import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../core/notificaciones.dart';
import '../../core/widgets/componentes.dart';
import '../ganado/ficha_animal_screen.dart';
import '../shell/app_shell.dart';

// HU-41: centro de notificaciones del usuario.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _api = ApiClient();
  List<Notificacion>? _notificaciones;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final lista = await _api.listarNotificaciones();
      if (!mounted) return;
      setState(() {
        _notificaciones = lista;
        _error = null;
      });
      _actualizarCampana();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo conectar con el servidor.');
    }
  }

  void _actualizarCampana() =>
      notificacionesNoLeidas.value = _notificaciones?.where((n) => !n.leida).length ?? notificacionesNoLeidas.value;

  void _marcarLocal(bool Function(Notificacion) cual) {
    setState(() {
      _notificaciones = [for (final n in _notificaciones!) cual(n) ? n.marcadaLeida() : n];
    });
    _actualizarCampana();
  }

  // Al abrirla se marca como leída y lleva al registro relacionado.
  Future<void> _abrir(Notificacion n) async {
    if (!n.leida) {
      try {
        await _api.marcarNotificacionLeida(n.id);
        if (mounted) _marcarLocal((x) => x.id == n.id);
      } catch (_) {
        // Si falla, igual se abre el registro; queda sin leer.
      }
    }
    if (!mounted) return;
    if (n.referenciaTipo == 'Animal') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FichaAnimalScreen(animalId: n.referenciaId)));
    } else if (n.referenciaTipo == 'Corral') {
      await Navigator.of(context).pushNamed('/corrales');
    }
  }

  Future<void> _marcarTodas() async {
    try {
      await _api.marcarTodasLeidas();
      if (mounted) _marcarLocal((_) => true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayNoLeidas = _notificaciones?.any((n) => !n.leida) ?? false;

    return AppShell(
      seccionActiva: '/notificaciones',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoPantalla(
              titulo: 'Notificaciones',
              subtitulo: 'Alertas de vacunas pendientes, corrales llenos y partos próximos.',
              acciones: [
                if (hayNoLeidas)
                  OutlinedButton.icon(
                    onPressed: _marcarTodas,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Marcar todas como leídas'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Card(margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias, child: _contenido()),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    final tema = Theme.of(context);
    final lista = _notificaciones;
    if (_error != null && lista == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (lista == null) {
      return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    }
    if (lista.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.notifications_none_outlined, size: 40, color: tema.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No tenés notificaciones', style: tema.textTheme.titleMedium),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final n in lista) ...[
          _FilaNotificacion(notificacion: n, onTap: () => _abrir(n)),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _FilaNotificacion extends StatelessWidget {
  const _FilaNotificacion({required this.notificacion, required this.onTap});

  final Notificacion notificacion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final n = notificacion;
    final (icono, color) = switch (n.tipo) {
      'VacunaPendiente' => (Icons.vaccines_outlined, tema.colorScheme.primary),
      'CorralLleno' => (Icons.fence, const Color(0xFFB7791F)),
      'PartoProximo' => (Icons.pregnant_woman, tema.colorScheme.tertiary),
      _ => (Icons.notifications_outlined, tema.colorScheme.onSurfaceVariant),
    };
    final hora = '${n.fecha.hour.toString().padLeft(2, '0')}:${n.fecha.minute.toString().padLeft(2, '0')}';

    return Material(
      color: n.leida ? Colors.transparent : tema.colorScheme.primary.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.mensaje,
                      style: tema.textTheme.bodyMedium?.copyWith(fontWeight: n.leida ? FontWeight.w400 : FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatearFecha(n.fecha)} $hora',
                      style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (!n.leida)
                Semantics(
                  label: 'Sin leer',
                  child: Container(
                    key: const ValueKey('sin-leer'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: tema.colorScheme.primary, shape: BoxShape.circle),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: tema.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
