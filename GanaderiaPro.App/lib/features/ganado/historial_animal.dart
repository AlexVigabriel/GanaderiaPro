import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../core/historial.dart';

// HU-22: línea de tiempo del animal (vacunaciones, tratamientos, pesajes,
// preñez/parto y movimientos de corral), de lo más reciente a lo más antiguo.
// Se carga al abrir «Historial».
class TarjetaHistorial extends StatefulWidget {
  const TarjetaHistorial({super.key, required this.animal});

  final Animal animal;

  @override
  State<TarjetaHistorial> createState() => _TarjetaHistorialState();
}

class _TarjetaHistorialState extends State<TarjetaHistorial> {
  Future<List<EventoHistorial>>? _eventos;

  void _cargar() => setState(() => _eventos = ApiClient().listarHistorial(widget.animal.id));

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        shape: const Border(),
        leading: Icon(Icons.history, color: tema.colorScheme.primary),
        title: Text('Historial', style: tema.textTheme.titleMedium),
        // Cada vez que se abre, se vuelve a pedir: puede haber eventos nuevos.
        onExpansionChanged: (abierto) {
          if (abierto) _cargar();
        },
        children: [
          FutureBuilder<List<EventoHistorial>>(
            future: _eventos,
            builder: (context, snapshot) {
              if (_eventos == null || snapshot.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        snapshot.error is ApiException
                            ? (snapshot.error as ApiException).mensaje
                            : 'No se pudo conectar con el servidor.',
                      ),
                    ),
                    TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                  ],
                );
              }
              final eventos = snapshot.data!;
              if (eventos.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Sin registros',
                    style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < eventos.length; i++)
                    _FilaEvento(evento: eventos[i], ultima: i == eventos.length - 1),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilaEvento extends StatelessWidget {
  const _FilaEvento({required this.evento, required this.ultima});

  final EventoHistorial evento;
  final bool ultima;

  static IconData _icono(String tipo) => switch (tipo) {
    'Vacunacion' => Icons.vaccines_outlined,
    'Tratamiento' => Icons.medication_outlined,
    'Pesaje' => Icons.monitor_weight_outlined,
    'Servicio' => Icons.favorite_border,
    'Parto' => Icons.child_friendly,
    'MovimientoCorral' => Icons.fence,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final suave = tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant);
    final quien = evento.usuario == null ? '' : ' · ${evento.usuario}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Punto y línea de la línea de tiempo.
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tema.colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icono(evento.tipo), size: 18, color: tema.colorScheme.primary),
                ),
                if (!ultima) Expanded(child: Container(width: 2, color: tema.colorScheme.outlineVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombreDeTipoDeEvento(evento.tipo), style: tema.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(evento.descripcion),
                  const SizedBox(height: 2),
                  Text('${formatearFecha(evento.fecha)}$quien', style: suave),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
