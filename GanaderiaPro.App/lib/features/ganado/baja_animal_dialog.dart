import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/catalogos.dart';
import '../../core/formato.dart';
import '../../core/validaciones_animal.dart';
import '../../core/widgets/componentes.dart';

// HU-54: marca como fallecido a un animal activo (botón de la calavera).
// Devuelve el animal actualizado, o null si se canceló.
Future<Animal?> abrirRegistroBaja(BuildContext context, Animal animal) =>
    showDialog<Animal>(context: context, builder: (_) => _MarcarFallecido(animal: animal));

// Mismas reglas que el servidor (RN-14 y no antes del nacimiento).
String? validarFechaBaja(DateTime? fecha, DateTime? nacimiento, {String obligatoria = 'La fecha es obligatoria'}) {
  if (fecha == null) return obligatoria;
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  if (dia.isAfter(fechaDeHoy())) return 'La fecha no puede ser futura';
  if (nacimiento != null && dia.isBefore(nacimiento)) return 'No puede ser anterior al nacimiento';
  return null;
}

// Datos que se cargan al dar de baja: se comparten entre la calavera y Editar.
class DatosBajaFormulario {
  DatosBajaFormulario({this.fecha, this.causa, String? detalle, String? observacion})
    : detalle = TextEditingController(text: detalle ?? ''),
      observacion = TextEditingController(text: observacion ?? '');

  factory DatosBajaFormulario.desde(Animal animal) => DatosBajaFormulario(
    fecha: animal.fechaBaja,
    causa: animal.causaMuerte,
    detalle: animal.detalleCausaMuerte,
    observacion: animal.observacionBaja,
  );

  DateTime? fecha;
  String? causa;
  final TextEditingController detalle;
  final TextEditingController observacion;
  Map<String, String> errores = {};

  // Valida para el estado elegido; devuelve true si se puede enviar.
  bool validar(String estado, DateTime? nacimiento) {
    final fallecido = estado == 'Fallecido';
    errores = {
      'fecha': ?validarFechaBaja(
        fecha,
        nacimiento,
        obligatoria: fallecido ? 'La fecha de defunción es obligatoria' : 'La fecha de venta es obligatoria',
      ),
      if (fallecido && causa == null) 'causa': 'Elegí la causa de muerte',
      if (fallecido && causa == 'Otra' && detalle.text.trim().isEmpty) 'detalle': 'Escribí cuál fue la causa',
      'detalle': ?validarLargo(detalle.text, 100),
      'observacion': ?validarLargo(observacion.text, 500),
    };
    return errores.isEmpty;
  }

  DatosEstado aDatos(String estado) {
    final fallecido = estado == 'Fallecido';
    final nota = observacion.text.trim();
    return DatosEstado(
      estado: estado,
      fecha: fecha,
      observacion: nota.isEmpty ? null : nota,
      causa: fallecido ? causa : null,
      detalleCausa: fallecido && causa == 'Otra' ? detalle.text.trim() : null,
    );
  }

  void dispose() {
    detalle.dispose();
    observacion.dispose();
  }
}

// Campos de la baja según el estado: Vendido pide fecha de venta;
// Fallecido pide fecha de defunción y causa (con detalle si es "Otra").
class CamposBaja extends StatelessWidget {
  const CamposBaja({
    super.key,
    required this.estado,
    required this.datos,
    required this.nacimiento,
    required this.onCambio,
  });

  final String estado;
  final DatosBajaFormulario datos;
  final DateTime? nacimiento;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final fallecido = estado == 'Fallecido';
    final etiquetaFecha = fallecido ? 'Fecha de defunción' : 'Fecha de venta';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Etiqueta('$etiquetaFecha *'),
        CampoFecha(
          valor: datos.fecha,
          titulo: etiquetaFecha,
          primeraFecha: nacimiento,
          errorText: datos.errores['fecha'],
          onChanged: (f) {
            datos.fecha = f;
            datos.errores.remove('fecha');
            onCambio();
          },
        ),
        if (fallecido) ...[
          const SizedBox(height: 16),
          const _Etiqueta('Causa de muerte *'),
          DropdownButtonFormField<String>(
            initialValue: datos.causa,
            isExpanded: true,
            decoration: InputDecoration(hintText: 'Seleccionar causa', errorText: datos.errores['causa']),
            items: [
              for (final c in causasMuerte.entries) DropdownMenuItem(value: c.key, child: Text(c.value)),
            ],
            onChanged: (v) {
              datos.causa = v;
              datos.errores.remove('causa');
              onCambio();
            },
          ),
          if (datos.causa == 'Otra') ...[
            const SizedBox(height: 16),
            const _Etiqueta('¿Cuál fue la causa? *'),
            TextField(
              controller: datos.detalle,
              maxLength: 100,
              decoration: InputDecoration(hintText: 'Ej. mordedura de víbora', errorText: datos.errores['detalle']),
            ),
          ],
        ],
        const SizedBox(height: 16),
        const _Etiqueta('Notas adicionales'),
        TextField(
          controller: datos.observacion,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: fallecido ? 'Observaciones sobre la defunción…' : 'Ej. comprador, precio, lugar de venta…',
            errorText: datos.errores['observacion'],
          ),
        ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(texto, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _MarcarFallecido extends StatefulWidget {
  const _MarcarFallecido({required this.animal});

  final Animal animal;

  @override
  State<_MarcarFallecido> createState() => _MarcarFallecidoState();
}

class _MarcarFallecidoState extends State<_MarcarFallecido> {
  final _api = ApiClient();
  final _datos = DatosBajaFormulario(fecha: fechaDeHoy());
  String? _errorServidor;
  bool _guardando = false;

  @override
  void dispose() {
    _datos.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final valido = _datos.validar('Fallecido', widget.animal.fechaNacimiento);
    setState(() => _errorServidor = null);
    if (!valido) return;

    setState(() => _guardando = true);
    try {
      final actualizado = await _api.registrarBaja(widget.animal.id, _datos.aDatos('Fallecido'));
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
    final rojo = tema.colorScheme.error;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 24),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconoCalavera(color: rojo, tamano: 26),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Marcar como fallecido', style: tema.textTheme.titleLarge)),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ResumenAnimal(animal: widget.animal, fechaDefuncion: _datos.fecha),
                const SizedBox(height: 24),
                CamposBaja(
                  estado: 'Fallecido',
                  datos: _datos,
                  nacimiento: widget.animal.fechaNacimiento,
                  onCambio: () => setState(() {}),
                ),
                if (_errorServidor != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorServidor!, style: tema.textTheme.bodyMedium?.copyWith(color: rojo)),
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
                      style: FilledButton.styleFrom(backgroundColor: rojo, foregroundColor: tema.colorScheme.onError),
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: tema.colorScheme.onError),
                            )
                          : const Text('Marcar como fallecido'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Recuadro con los datos del animal y la edad que tenía al morir.
class _ResumenAnimal extends StatelessWidget {
  const _ResumenAnimal({required this.animal, required this.fechaDefuncion});

  final Animal animal;
  final DateTime? fechaDefuncion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nacimiento = animal.fechaNacimiento;
    final datos = <(String, String)>[
      ('Nombre', animal.nombre ?? '—'),
      ('Identificación', animal.arete),
      ('Sexo', animal.sexo),
      ('Raza', animal.raza),
      ('Fecha de nacimiento', nacimiento == null ? '—' : formatearFecha(nacimiento)),
      (
        'Edad al morir',
        nacimiento == null || fechaDefuncion == null || fechaDefuncion!.isBefore(nacimiento)
            ? '—'
            : describirEdad(nacimiento, hasta: fechaDefuncion),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final ancho = (restricciones.maxWidth - 16) / 2;
          return Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final (etiqueta, valor) in datos)
                SizedBox(
                  width: ancho,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etiqueta,
                        style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(valor, style: tema.textTheme.bodyLarge),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
