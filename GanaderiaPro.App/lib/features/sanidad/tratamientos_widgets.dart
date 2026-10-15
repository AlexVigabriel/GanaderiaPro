import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../core/sanidad.dart';
import '../../core/validaciones_animal.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/selector_animales.dart';

// HU-57: registrar un tratamiento. Desde la ficha llega el animal; desde
// Sanidad se elige. Devuelve true si se guardó.
Future<bool> abrirRegistroTratamiento(BuildContext context, {Animal? animal}) async {
  final guardado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RegistroTratamiento(animal: animal),
  );
  return guardado ?? false;
}

class _RegistroTratamiento extends StatefulWidget {
  const _RegistroTratamiento({this.animal});

  final Animal? animal;

  @override
  State<_RegistroTratamiento> createState() => _RegistroTratamientoState();
}

class _RegistroTratamientoState extends State<_RegistroTratamiento> {
  final _api = ApiClient();
  final _motivo = TextEditingController();
  final _medicamento = TextEditingController();
  final _dosis = TextEditingController();
  final _duracion = TextEditingController();
  final _observacion = TextEditingController();
  late List<Animal> _animales = [?widget.animal];
  DateTime? _inicio = fechaDeHoy();
  Map<String, String> _errores = {};
  String? _errorGeneral;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_motivo, _medicamento, _dosis, _duracion, _observacion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirAnimal() async {
    final elegidos = await elegirAnimales(context, iniciales: _animales);
    if (elegidos != null) {
      setState(() {
        _animales = elegidos;
        _errores = {..._errores}..remove('animal');
      });
    }
  }

  // Las mismas reglas que el servidor.
  Map<String, String> _validar() {
    String? obligatorio(TextEditingController c, int largo, String nombre) {
      final texto = c.text.trim();
      if (texto.isEmpty) return '$nombre es obligatorio';
      if (texto.length > largo) return 'Hasta $largo caracteres';
      return null;
    }

    final duracion = int.tryParse(_duracion.text.trim());
    final nacimiento = _animales.length == 1 ? _animales.first.fechaNacimiento : null;
    return {
      if (_animales.length != 1) 'animal': 'Elegí un solo animal',
      'motivo': ?obligatorio(_motivo, 200, 'El motivo'),
      'medicamento': ?obligatorio(_medicamento, 150, 'El medicamento'),
      'dosis': ?obligatorio(_dosis, 100, 'La dosis'),
      if (_inicio == null) 'inicio': 'Elegí la fecha de inicio',
      if (_inicio != null && nacimiento != null && _inicio!.isBefore(nacimiento))
        'inicio': 'No puede ser anterior al nacimiento',
      if (duracion == null || duracion < 1 || duracion > 365) 'duracion': 'De 1 a 365 días',
      if (_observacion.text.trim().length > 500) 'observacion': 'Hasta 500 caracteres',
    };
  }

  Future<void> _guardar() async {
    final errores = _validar();
    setState(() {
      _errores = errores;
      _errorGeneral = null;
    });
    if (errores.isNotEmpty) return;

    setState(() => _guardando = true);
    try {
      final observacion = _observacion.text.trim();
      await _api.registrarTratamiento(
        _animales.single.id,
        DatosTratamiento(
          motivo: _motivo.text.trim(),
          medicamento: _medicamento.text.trim(),
          dosis: _dosis.text.trim(),
          fechaInicio: _inicio!,
          duracionDias: int.parse(_duracion.text.trim()),
          observacion: observacion.isEmpty ? null : observacion,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorGeneral = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _errorGeneral = 'No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  InputDecoration _decoracion(String etiqueta, String clave, {String? hint, String? sufijo}) =>
      InputDecoration(labelText: etiqueta, hintText: hint, suffixText: sufijo, errorText: _errores[clave]);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final desdeFicha = widget.animal != null;

    return AlertDialog(
      title: Text(desdeFicha ? 'Registrar tratamiento · ${widget.animal!.arete}' : 'Registrar tratamiento'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorGeneral != null) ...[
                Text(_errorGeneral!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
                const SizedBox(height: 12),
              ],
              if (!desdeFicha) ...[
                Text('Animal', style: tema.textTheme.labelLarge),
                const SizedBox(height: 6),
                CampoAnimales(elegidos: _animales, error: _errores['animal'], onElegir: _guardando ? null : _elegirAnimal),
                const SizedBox(height: 16),
              ],
              TextField(controller: _motivo, decoration: _decoracion('Motivo o diagnóstico', 'motivo', hint: 'Ej. Neumonía')),
              const SizedBox(height: 12),
              TextField(controller: _medicamento, decoration: _decoracion('Medicamento', 'medicamento')),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: TextField(controller: _dosis, decoration: _decoracion('Dosis', 'dosis', hint: 'Ej. 10 ml'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _duracion,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _decoracion('Duración', 'duracion', sufijo: 'días'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Fecha de inicio', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              CampoFecha(
                valor: _inicio,
                titulo: 'Fecha de inicio',
                errorText: _errores['inicio'],
                onChanged: (f) => setState(() => _inicio = f),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _observacion,
                maxLines: 2,
                decoration: _decoracion('Observación (opcional)', 'observacion'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar tratamiento'),
        ),
      ],
    );
  }
}

// Lista de tratamientos de un animal, separada de las vacunas.
class ListaTratamientos extends StatelessWidget {
  const ListaTratamientos({super.key, required this.tratamientos});

  final List<Tratamiento> tratamientos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (tratamientos.isEmpty) {
      return Text(
        'Este animal no tiene tratamientos registrados.',
        style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
      );
    }
    return Column(children: [for (final t in tratamientos) _FilaTratamiento(tratamiento: t)]);
  }
}

class _FilaTratamiento extends StatelessWidget {
  const _FilaTratamiento({required this.tratamiento});

  final Tratamiento tratamiento;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final t = tratamiento;
    final color = t.enCurso ? const Color(0xFFB7791F) : tema.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tema.colorScheme.outlineVariant))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.medication_outlined, size: 20, color: tema.colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.motivo} · ${t.medicamento} (${t.dosis})', style: tema.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  '${formatearFecha(t.fechaInicio)} al ${formatearFecha(t.fechaFin)} · '
                  '${t.duracionDias == 1 ? '1 día' : '${t.duracionDias} días'} · ${t.veterinario}',
                  style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
                if (t.observacion != null)
                  Text(t.observacion!, style: tema.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              t.enCurso ? 'En curso' : 'Finalizado',
              style: tema.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
