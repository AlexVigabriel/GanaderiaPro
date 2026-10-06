import 'package:flutter/material.dart';

import '../animal.dart';
import '../api_client.dart';

String textoAnimal(Animal animal) => animal.nombre == null ? animal.arete : '${animal.arete} · ${animal.nombre}';

// Abre la lista de animales activos con búsqueda y casillas. Devuelve los
// elegidos, o null si se canceló. Se usa en Sanidad y en Corrales.
Future<List<Animal>?> elegirAnimales(BuildContext context, {List<Animal> iniciales = const []}) =>
    showDialog<List<Animal>>(context: context, builder: (_) => _Selector(iniciales: iniciales));

// Muestra los animales elegidos y el botón para cambiarlos.
class CampoAnimales extends StatelessWidget {
  const CampoAnimales({super.key, required this.elegidos, required this.error, required this.onElegir});

  final List<Animal> elegidos;
  final String? error;
  final VoidCallback? onElegir;

  static const _maximoVisibles = 8;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colorBorde = error == null ? tema.colorScheme.outlineVariant : tema.colorScheme.error;
    final visibles = elegidos.take(_maximoVisibles).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorBorde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (elegidos.isEmpty)
                Text(
                  'Ningún animal elegido.',
                  style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in visibles) Chip(label: Text(a.arete), visualDensity: VisualDensity.compact),
                    if (elegidos.length > visibles.length)
                      Chip(label: Text('+${elegidos.length - visibles.length} más'), visualDensity: VisualDensity.compact),
                  ],
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onElegir,
                icon: const Icon(Icons.checklist, size: 18),
                label: Text(elegidos.isEmpty ? 'Elegir animales' : 'Cambiar selección (${elegidos.length})'),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(error!, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error)),
          ),
      ],
    );
  }
}

// Lista de animales activos con búsqueda y casillas; "Todos" elige los que
// se ven con el filtro actual.
class _Selector extends StatefulWidget {
  const _Selector({required this.iniciales});

  final List<Animal> iniciales;

  @override
  State<_Selector> createState() => _SelectorState();
}

class _SelectorState extends State<_Selector> {
  late final Future<List<Animal>> _animales = ApiClient().buscarAnimales(estado: 'Activo');
  late final _elegidos = {for (final a in widget.iniciales) a.id: a};
  String _filtro = '';

  List<Animal> _visibles(List<Animal> todos) {
    final f = _filtro.trim().toLowerCase();
    if (f.isEmpty) return todos;
    return todos
        .where((a) => a.arete.toLowerCase().contains(f) || (a.nombre ?? '').toLowerCase().contains(f) || a.raza.toLowerCase().contains(f))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: FutureBuilder<List<Animal>>(
            future: _animales,
            builder: (context, snapshot) {
              final todos = snapshot.data ?? const <Animal>[];
              final visibles = _visibles(todos);
              final todosVisiblesElegidos = visibles.isNotEmpty && visibles.every((a) => _elegidos.containsKey(a.id));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Elegir animales', style: tema.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Buscar por identificación, nombre o raza…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _filtro = v),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: todosVisiblesElegidos,
                    title: Text(_filtro.trim().isEmpty ? 'Todos los animales activos' : 'Todos los de la búsqueda'),
                    subtitle: Text('${_elegidos.length} elegidos'),
                    onChanged: visibles.isEmpty
                        ? null
                        : (marcar) => setState(() {
                            for (final a in visibles) {
                              marcar == true ? _elegidos[a.id] = a : _elegidos.remove(a.id);
                            }
                          }),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: snapshot.connectionState != ConnectionState.done
                        ? const Center(child: CircularProgressIndicator())
                        : snapshot.hasError
                        ? const Center(child: Text('No se pudo cargar la lista de animales.'))
                        : visibles.isEmpty
                        ? const Center(child: Text('No hay animales activos que coincidan.'))
                        : ListView.builder(
                            itemCount: visibles.length,
                            itemBuilder: (context, i) {
                              final a = visibles[i];
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: _elegidos.containsKey(a.id),
                                title: Text(textoAnimal(a)),
                                subtitle: Text(['${a.raza} · ${a.categoria ?? a.sexo}', if (a.corral != null) 'en ${a.corral}'].join(' · ')),
                                onChanged: (marcar) => setState(() {
                                  marcar == true ? _elegidos[a.id] = a : _elegidos.remove(a.id);
                                }),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(_elegidos.values.toList()),
                        child: Text('Listo (${_elegidos.length})'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
