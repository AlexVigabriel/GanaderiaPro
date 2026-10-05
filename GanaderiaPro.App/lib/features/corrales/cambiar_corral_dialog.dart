import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/corral.dart';

// Cambia el corral de un animal o lo deja sin corral. Los corrales llenos no
// se pueden elegir (RN-07). Devuelve true si se guardó.
Future<bool?> abrirCambioCorral(BuildContext context, Animal animal) =>
    showDialog<bool>(context: context, builder: (_) => _CambioCorral(animal: animal));

// Un corral se puede elegir si tiene lugar o si ya es el del animal.
bool corralDisponible(Corral corral, String? corralActual) => corral.id == corralActual || corral.lugaresLibres > 0;

class _CambioCorral extends StatefulWidget {
  const _CambioCorral({required this.animal});

  final Animal animal;

  @override
  State<_CambioCorral> createState() => _CambioCorralState();
}

class _CambioCorralState extends State<_CambioCorral> {
  final _api = ApiClient();
  late final Future<List<Corral>> _corrales = _api.listarCorrales();
  late String? _elegido = widget.animal.corralId;
  String? _error;
  bool _guardando = false;

  Future<void> _guardar() async {
    if (_elegido == widget.animal.corralId) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _api.asignarCorral(widget.animal.id, _elegido);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final suave = tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant);

    return AlertDialog(
      icon: Icon(Icons.fence, color: tema.colorScheme.primary, size: 30),
      title: Text('Corral de ${widget.animal.arete}'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<Corral>>(
          future: _corrales,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) return const Text('No se pudieron cargar los corrales.');

            final corrales = snapshot.data!;
            return RadioGroup<String?>(
              groupValue: _elegido,
              onChanged: (v) => setState(() => _elegido = v),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String?>(
                      value: null,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sin corral'),
                    ),
                    for (final c in corrales)
                      RadioListTile<String?>(
                        value: c.id,
                        enabled: corralDisponible(c, widget.animal.corralId),
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.nombre),
                        subtitle: Text(
                          c.id == widget.animal.corralId
                              ? 'Corral actual · ${c.animalesActivos}/${c.capacidad}'
                              : (c.lugaresLibres > 0
                                    ? '${c.animalesActivos}/${c.capacidad} · ${c.lugaresLibres} lugares libres'
                                    : 'Lleno (${c.animalesActivos}/${c.capacidad})'),
                          style: suave,
                        ),
                      ),
                    if (corrales.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('No hay corrales activos. Crealos desde el módulo Corrales.', style: suave),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
