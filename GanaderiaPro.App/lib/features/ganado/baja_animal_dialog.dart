import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/validaciones_animal.dart';
import '../../core/widgets/componentes.dart';

// HU-54: registra la baja (venta o fallecimiento) de un animal activo.
// Devuelve el animal actualizado, o null si se canceló.
Future<Animal?> abrirRegistroBaja(BuildContext context, Animal animal) =>
    showDialog<Animal>(context: context, builder: (_) => _RegistroBaja(animal: animal));

// Mismas reglas que el servidor (RN-14 y no antes del nacimiento).
String? validarFechaBaja(DateTime? fecha, DateTime? nacimiento) {
  if (fecha == null) return 'La fecha de baja es obligatoria';
  final ahora = DateTime.now();
  if (fecha.isAfter(DateTime(ahora.year, ahora.month, ahora.day))) return 'La fecha de baja no puede ser futura';
  if (nacimiento != null && fecha.isBefore(nacimiento)) return 'No puede ser anterior al nacimiento';
  return null;
}

class _RegistroBaja extends StatefulWidget {
  const _RegistroBaja({required this.animal});

  final Animal animal;

  @override
  State<_RegistroBaja> createState() => _RegistroBajaState();
}

class _RegistroBajaState extends State<_RegistroBaja> {
  final _api = ApiClient();
  final _observacion = TextEditingController();
  String _tipo = 'Venta';
  DateTime? _fecha = DateTime.now();
  String? _errorFecha;
  String? _errorObservacion;
  String? _errorServidor;
  bool _guardando = false;

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _errorFecha = validarFechaBaja(_fecha, widget.animal.fechaNacimiento);
      _errorObservacion = validarLargo(_observacion.text, 500);
      _errorServidor = null;
    });
    if (_errorFecha != null || _errorObservacion != null) return;

    setState(() => _guardando = true);
    try {
      final texto = _observacion.text.trim();
      final actualizado = await _api.registrarBaja(
        widget.animal.id,
        tipo: _tipo,
        fecha: _fecha!,
        observacion: texto.isEmpty ? null : texto,
      );
      if (mounted) Navigator.of(context).pop(actualizado);
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
    final etiqueta = tema.textTheme.labelLarge;

    return AlertDialog(
      icon: IconoCalavera(color: tema.colorScheme.error, tamano: 32),
      title: Text('Registrar baja de ${widget.animal.arete}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'El animal deja de contarse como activo, pero conserva todos sus datos.',
                style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Text('Motivo *', style: etiqueta),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Venta', label: Text('Venta'), icon: Icon(Icons.sell_outlined)),
                  ButtonSegment(value: 'Fallecimiento', label: Text('Fallecimiento'), icon: Icon(Icons.heart_broken_outlined)),
                ],
                selected: {_tipo},
                onSelectionChanged: _guardando ? null : (v) => setState(() => _tipo = v.first),
              ),
              const SizedBox(height: 16),
              Text('Fecha de baja *', style: etiqueta),
              const SizedBox(height: 6),
              CampoFecha(
                valor: _fecha,
                titulo: 'Fecha de baja',
                primeraFecha: widget.animal.fechaNacimiento,
                errorText: _errorFecha,
                onChanged: (f) => setState(() {
                  _fecha = f;
                  _errorFecha = null;
                }),
              ),
              const SizedBox(height: 16),
              Text('Observación', style: etiqueta),
              const SizedBox(height: 6),
              TextField(
                controller: _observacion,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _tipo == 'Venta' ? 'Ej. vendido en feria a …' : 'Ej. causa del fallecimiento',
                  errorText: _errorObservacion,
                ),
              ),
              if (_errorServidor != null) ...[
                const SizedBox(height: 12),
                Text(_errorServidor!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: tema.colorScheme.error),
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Registrar baja'),
        ),
      ],
    );
  }
}
