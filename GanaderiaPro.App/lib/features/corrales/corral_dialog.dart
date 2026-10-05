import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/corral.dart';
import '../../core/widgets/selector_animales.dart';

// HU-23: crear un corral (con animales opcionales) o, con [editar],
// cambiarle el nombre y la capacidad. Devuelve el corral guardado.
Future<Corral?> abrirFormularioCorral(BuildContext context, {Corral? editar}) =>
    showDialog<Corral>(context: context, builder: (_) => _FormularioCorral(editar: editar));

// Mismas reglas que el servidor.
String? validarNombreCorral(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'El nombre es obligatorio';
  if (texto.length > 60) return 'Hasta 60 caracteres';
  return null;
}

String? validarCapacidad(String? valor) {
  final capacidad = int.tryParse(valor?.trim() ?? '');
  if (capacidad == null) return 'Ingresá un número entero';
  if (capacidad < 1 || capacidad > 10000) return 'Debe estar entre 1 y 10000';
  return null;
}

// RN-07: no se pueden asignar más animales que la capacidad.
String? validarOcupacion(int animales, int? capacidad) {
  if (capacidad == null || animales <= capacidad) return null;
  return 'La capacidad es $capacidad: quedan $capacidad lugares y elegiste $animales animales';
}

class _FormularioCorral extends StatefulWidget {
  const _FormularioCorral({this.editar});

  final Corral? editar;

  @override
  State<_FormularioCorral> createState() => _FormularioCorralState();
}

class _FormularioCorralState extends State<_FormularioCorral> {
  final _api = ApiClient();
  late final _nombre = TextEditingController(text: widget.editar?.nombre ?? '');
  late final _capacidad = TextEditingController(text: widget.editar?.capacidad.toString() ?? '');
  final _elegidos = <Animal>[];
  Map<String, String> _errores = {};
  String? _errorServidor;
  bool _guardando = false;

  bool get _editando => widget.editar != null;

  @override
  void dispose() {
    _nombre.dispose();
    _capacidad.dispose();
    super.dispose();
  }

  Future<void> _elegirAnimales() async {
    final elegidos = await elegirAnimales(context, iniciales: _elegidos);
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
        'nombre': ?validarNombreCorral(_nombre.text),
        'capacidad': ?validarCapacidad(_capacidad.text),
        'animales': ?validarOcupacion(_elegidos.length, int.tryParse(_capacidad.text.trim())),
      };
      _errorServidor = null;
    });
    if (_errores.isNotEmpty) return;

    setState(() => _guardando = true);
    try {
      final nombre = _nombre.text.trim();
      final capacidad = int.parse(_capacidad.text.trim());
      final corral = _editando
          ? await _api.editarCorral(widget.editar!.id, nombre: nombre, capacidad: capacidad)
          : await _api.crearCorral(nombre: nombre, capacidad: capacidad, animalIds: [for (final a in _elegidos) a.id]);
      if (mounted) Navigator.of(context).pop(corral);
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
    final capacidad = int.tryParse(_capacidad.text.trim());
    final enMovimiento = _elegidos.where((a) => a.corral != null).length;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.fence, color: tema.colorScheme.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_editando ? 'Editar corral' : 'Nuevo corral', style: tema.textTheme.titleLarge)),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              etiqueta('Nombre *'),
              TextField(
                controller: _nombre,
                autofocus: true,
                decoration: InputDecoration(hintText: 'Ej. Corral Norte', errorText: _errores['nombre']),
              ),
              const SizedBox(height: 16),
              etiqueta('Capacidad máxima *'),
              TextField(
                controller: _capacidad,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                decoration: InputDecoration(
                  hintText: 'Ej. 25',
                  suffixText: 'animales',
                  errorText: _errores['capacidad'],
                ),
                onChanged: (_) => setState(() => _errores.remove('animales')),
              ),
              if (!_editando) ...[
                const SizedBox(height: 16),
                etiqueta('Animales (opcional)'),
                CampoAnimales(
                  elegidos: _elegidos,
                  error: _errores['animales'],
                  onElegir: _guardando ? null : _elegirAnimales,
                ),
                if (_elegidos.isNotEmpty && capacidad != null && _errores['animales'] == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      [
                        '${_elegidos.length} de $capacidad lugares',
                        if (enMovimiento > 0) '$enMovimiento se mueven desde otro corral',
                      ].join(' · '),
                      style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
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
                        : Text(_editando ? 'Guardar cambios' : 'Crear corral'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
