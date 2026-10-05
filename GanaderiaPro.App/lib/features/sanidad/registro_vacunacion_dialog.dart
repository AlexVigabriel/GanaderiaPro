import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/sanidad.dart';
import '../../core/validaciones_animal.dart';
import '../../core/widgets/componentes.dart';
import '../ganado/baja_animal_dialog.dart';

// HU-26: formulario de vacunación.
// - Sin [animal] ni [editar]: se eligen uno o varios animales activos.
// - Con [animal]: vacuna a ese animal (desde su ficha o una pendiente).
// - Con [editar]: corrige una vacunación ya registrada.
// Devuelve cuántas vacunaciones se guardaron, o null si se canceló.
Future<int?> abrirRegistroVacunacion(
  BuildContext context, {
  Animal? animal,
  Vacunacion? editar,
  String? vacunaInicial,
}) => showDialog<int>(
  context: context,
  builder: (_) => _RegistroVacunacion(animal: animal, editar: editar, vacunaInicial: vacunaInicial),
);

// Mismas reglas que el servidor.
String? validarDosis(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'La dosis es obligatoria';
  if (texto.length > 50) return 'Hasta 50 caracteres';
  return null;
}

String? validarProximaDosis(DateTime? proxima, DateTime? aplicacion) {
  if (proxima == null || aplicacion == null) return null;
  return proxima.isBefore(aplicacion) ? 'No puede ser anterior a la aplicación' : null;
}

class _RegistroVacunacion extends StatefulWidget {
  const _RegistroVacunacion({this.animal, this.editar, this.vacunaInicial});

  final Animal? animal;
  final Vacunacion? editar;
  final String? vacunaInicial;

  @override
  State<_RegistroVacunacion> createState() => _RegistroVacunacionState();
}

class _RegistroVacunacionState extends State<_RegistroVacunacion> {
  final _api = ApiClient();
  late final _dosis = TextEditingController(text: widget.editar?.dosis ?? '');
  late final _observacion = TextEditingController(text: widget.editar?.observacion ?? '');
  late Future<List<Vacuna>> _vacunas = _api.listarVacunas();
  late String? _vacunaId = widget.editar?.vacunaId ?? widget.vacunaInicial;
  late DateTime? _aplicacion = widget.editar?.fechaAplicacion ?? fechaDeHoy();
  late DateTime? _proxima = widget.editar?.fechaProximaDosis;
  final _elegidos = <Animal>[];
  Map<String, String> _errores = {};
  String? _errorServidor;
  bool _guardando = false;

  bool get _editando => widget.editar != null;
  bool get _animalFijo => widget.animal != null || _editando;

  @override
  void initState() {
    super.initState();
    if (widget.animal != null) _elegidos.add(widget.animal!);
  }

  @override
  void dispose() {
    _dosis.dispose();
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _elegirAnimales() async {
    final elegidos = await showDialog<List<Animal>>(
      context: context,
      builder: (_) => _SelectorAnimales(iniciales: _elegidos),
    );
    if (elegidos == null) return;
    setState(() {
      _elegidos
        ..clear()
        ..addAll(elegidos);
      _errores.remove('animales');
    });
  }

  Future<void> _guardar() async {
    setState(() {
      _errores = {
        if (!_animalFijo && _elegidos.isEmpty) 'animales': 'Elegí al menos un animal',
        if (_vacunaId == null) 'vacuna': 'Elegí la vacuna',
        'dosis': ?validarDosis(_dosis.text),
        'aplicacion': ?validarFechaBaja(
          _aplicacion,
          widget.animal?.fechaNacimiento,
          obligatoria: 'La fecha de aplicación es obligatoria',
        ),
        'proxima': ?validarProximaDosis(_proxima, _aplicacion),
        'observacion': ?validarLargo(_observacion.text, 500),
      };
      _errorServidor = null;
    });
    if (_errores.isNotEmpty) return;

    final nota = _observacion.text.trim();
    final datos = DatosVacunacion(
      vacunaId: _vacunaId!,
      dosis: _dosis.text.trim(),
      fechaAplicacion: _aplicacion!,
      fechaProximaDosis: _proxima,
      observacion: nota.isEmpty ? null : nota,
    );

    setState(() => _guardando = true);
    try {
      if (_editando) {
        await _api.editarVacunacion(widget.editar!.id, datos);
        if (mounted) Navigator.of(context).pop(1);
      } else {
        final cantidad = await _api.registrarVacunacion([for (final a in _elegidos) a.id], datos);
        if (mounted) Navigator.of(context).pop(cantidad);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorServidor = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _errorServidor = 'No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget etiqueta(String texto) =>
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(texto, style: tema.textTheme.labelLarge));

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.vaccines_outlined, color: tema.colorScheme.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _editando ? 'Editar vacunación' : 'Registrar vacunación',
                      style: tema.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              etiqueta(_animalFijo ? 'Animal' : 'Animales *'),
              if (_animalFijo)
                _ResumenAnimal(texto: widget.editar?.animal ?? _textoAnimal(widget.animal!))
              else
                _CampoAnimales(
                  elegidos: _elegidos,
                  error: _errores['animales'],
                  onElegir: _guardando ? null : _elegirAnimales,
                ),
              const SizedBox(height: 16),
              etiqueta('Vacuna *'),
              FutureBuilder<List<Vacuna>>(
                future: _vacunas,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return TextButton.icon(
                      onPressed: () => setState(() => _vacunas = _api.listarVacunas()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('No se pudo cargar la lista de vacunas. Reintentar'),
                    );
                  }
                  final vacunas = snapshot.data ?? const <Vacuna>[];
                  return DropdownButtonFormField<String>(
                    key: ValueKey(vacunas.length),
                    initialValue: vacunas.any((v) => v.id == _vacunaId) ? _vacunaId : null,
                    isExpanded: true,
                    decoration: InputDecoration(hintText: 'Seleccionar vacuna', errorText: _errores['vacuna']),
                    items: [for (final v in vacunas) DropdownMenuItem(value: v.id, child: Text(v.nombre))],
                    onChanged: (v) => setState(() {
                      _vacunaId = v;
                      _errores.remove('vacuna');
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
              etiqueta('Dosis *'),
              TextField(
                controller: _dosis,
                decoration: InputDecoration(hintText: 'Ej. 5 ml', errorText: _errores['dosis']),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, restricciones) {
                  final ancho = restricciones.maxWidth >= 440 ? (restricciones.maxWidth - 16) / 2 : restricciones.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: ancho,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            etiqueta('Fecha de aplicación *'),
                            CampoFecha(
                              valor: _aplicacion,
                              titulo: 'Fecha de aplicación',
                              primeraFecha: widget.animal?.fechaNacimiento,
                              errorText: _errores['aplicacion'],
                              onChanged: (f) => setState(() {
                                _aplicacion = f;
                                _errores.remove('aplicacion');
                              }),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: ancho,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            etiqueta('Próxima dosis'),
                            CampoFecha(
                              valor: _proxima,
                              titulo: 'Próxima dosis',
                              hint: 'Opcional',
                              primeraFecha: _aplicacion ?? fechaDeHoy(),
                              ultimaFecha: DateTime(fechaDeHoy().year + 5, 12, 31),
                              errorText: _errores['proxima'],
                              onChanged: (f) => setState(() {
                                _proxima = f;
                                _errores.remove('proxima');
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              etiqueta('Observaciones'),
              TextField(
                controller: _observacion,
                maxLines: 2,
                decoration: InputDecoration(hintText: 'Ej. lote, laboratorio', errorText: _errores['observacion']),
              ),
              const SizedBox(height: 8),
              Text(
                'Veterinario responsable: el usuario que inició sesión.',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              if (_errorServidor != null) ...[
                const SizedBox(height: 12),
                Text(_errorServidor!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_textoBoton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _textoBoton {
    if (_editando) return 'Guardar cambios';
    if (_animalFijo || _elegidos.length <= 1) return 'Registrar vacunación';
    return 'Vacunar ${_elegidos.length} animales';
  }
}

String _textoAnimal(Animal animal) => animal.nombre == null ? animal.arete : '${animal.arete} · ${animal.nombre}';

class _ResumenAnimal extends StatelessWidget {
  const _ResumenAnimal({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.pets_outlined, size: 18, color: tema.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: tema.textTheme.titleSmall)),
        ],
      ),
    );
  }
}

// Muestra los animales elegidos y el botón para cambiarlos.
class _CampoAnimales extends StatelessWidget {
  const _CampoAnimales({required this.elegidos, required this.error, required this.onElegir});

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
class _SelectorAnimales extends StatefulWidget {
  const _SelectorAnimales({required this.iniciales});

  final List<Animal> iniciales;

  @override
  State<_SelectorAnimales> createState() => _SelectorAnimalesState();
}

class _SelectorAnimalesState extends State<_SelectorAnimales> {
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
                                title: Text(_textoAnimal(a)),
                                subtitle: Text('${a.raza} · ${a.categoria ?? a.sexo}'),
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
