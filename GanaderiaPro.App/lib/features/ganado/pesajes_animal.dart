import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../core/validaciones_animal.dart';
import '../../core/widgets/componentes.dart';
import 'baja_animal_dialog.dart';

// HU-55: historial de pesajes en la ficha del animal, con el botón para
// registrar uno nuevo (solo animales activos).
class TarjetaPesajes extends StatefulWidget {
  const TarjetaPesajes({super.key, required this.animal, required this.onPesoActualizado});

  final Animal animal;
  // La ficha se recarga para mostrar el peso actual nuevo.
  final VoidCallback onPesoActualizado;

  @override
  State<TarjetaPesajes> createState() => _TarjetaPesajesState();
}

class _TarjetaPesajesState extends State<TarjetaPesajes> {
  final _api = ApiClient();
  late Future<List<Pesaje>> _futuro = _api.listarPesajes(widget.animal.id);

  // pesaje == null registra uno nuevo; si no, lo edita.
  Future<void> _abrirFormulario([Pesaje? pesaje]) async {
    final historial = await _futuro.catchError((_) => <Pesaje>[]);
    if (!mounted) return;
    final guardado = await abrirRegistroPesaje(context, widget.animal, historial: historial, pesaje: pesaje);
    if (guardado == true) _actualizar(pesaje == null ? 'Pesaje registrado.' : 'Pesaje corregido.');
  }

  // Para corregir un pesaje cargado por error.
  Future<void> _eliminar(Pesaje pesaje) async {
    final tema = Theme.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este pesaje?'),
        content: Text(
          '${formatearFecha(pesaje.fecha)} · ${formatearPeso(pesaje.peso)}. '
          'El peso actual del animal se recalcula con los pesajes que queden.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: tema.colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await _api.eliminarPesaje(widget.animal.id, pesaje.id);
      _actualizar('Pesaje eliminado.');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
      }
    }
  }

  void _actualizar(String mensaje) {
    if (!mounted) return;
    setState(() {
      _futuro = _api.listarPesajes(widget.animal.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    widget.onPesoActualizado();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text('Historial de pesajes', style: tema.textTheme.titleMedium),
                if (widget.animal.activo)
                  FilledButton.icon(
                    onPressed: _abrirFormulario,
                    icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                    label: const Text('Registrar pesaje'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Pesaje>>(
              future: _futuro,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'No se pudo cargar el historial de pesajes.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error),
                  );
                }
                final pesajes = snapshot.data!;
                if (pesajes.isEmpty) {
                  return Text(
                    widget.animal.activo
                        ? 'Todavía no hay pesajes. Registrá el primero para seguir su desarrollo.'
                        : 'Este animal no tiene pesajes registrados.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pesajes.length >= 2) ...[
                      SizedBox(height: 150, child: _GraficoPesos(pesajes: pesajes)),
                      const SizedBox(height: 16),
                    ],
                    for (var i = 0; i < pesajes.length; i++)
                      _FilaPesaje(
                        pesaje: pesajes[i],
                        anterior: i + 1 < pesajes.length ? pesajes[i + 1] : null,
                        // Solo se corrigen pesajes de animales activos.
                        onEditar: widget.animal.activo ? () => _abrirFormulario(pesajes[i]) : null,
                        onEliminar: widget.animal.activo ? () => _eliminar(pesajes[i]) : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Una fila del historial: fecha, peso y cuánto cambió respecto del anterior.
class _FilaPesaje extends StatelessWidget {
  const _FilaPesaje({required this.pesaje, required this.anterior, this.onEditar, this.onEliminar});

  final Pesaje pesaje;
  final Pesaje? anterior;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final diferencia = anterior == null ? null : pesaje.peso - anterior!.peso;
    final color = diferencia == null || diferencia == 0
        ? tema.colorScheme.onSurfaceVariant
        : (diferencia > 0 ? tema.colorScheme.primary : tema.colorScheme.error);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: tema.colorScheme.outlineVariant))),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(formatearFecha(pesaje.fecha))),
          SizedBox(
            width: 100,
            child: Text(formatearPeso(pesaje.peso), style: tema.textTheme.titleSmall),
          ),
          SizedBox(
            width: 90,
            child: diferencia == null
                ? const SizedBox.shrink()
                : Text(
                    '${diferencia > 0 ? '+' : ''}${formatearPeso(diferencia)}',
                    style: tema.textTheme.labelLarge?.copyWith(color: color),
                  ),
          ),
          Expanded(
            child: Text(
              pesaje.observacion ?? '',
              style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
          if (onEditar != null) ...[
            BotonAccion(icono: Icons.edit_outlined, tooltip: 'Editar pesaje', onPressed: onEditar),
            const SizedBox(width: 8),
          ],
          if (onEliminar != null)
            BotonAccion(icono: Icons.delete_outline, tooltip: 'Eliminar pesaje', peligro: true, onPressed: onEliminar),
        ],
      ),
    );
  }
}

// Evolución del peso: los puntos se separan según los días reales entre
// pesajes, con el peso mínimo y máximo a la izquierda y las fechas abajo.
class _GraficoPesos extends StatelessWidget {
  const _GraficoPesos({required this.pesajes});

  final List<Pesaje> pesajes;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _PintorPesos(
        pesajes: pesajes.reversed.toList(),
        linea: tema.colorScheme.primary,
        guia: tema.colorScheme.outlineVariant,
        texto: tema.textTheme.labelSmall!.copyWith(color: tema.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _PintorPesos extends CustomPainter {
  _PintorPesos({required this.pesajes, required this.linea, required this.guia, required this.texto});

  // Del más antiguo al más reciente.
  final List<Pesaje> pesajes;
  final Color linea;
  final Color guia;
  final TextStyle texto;

  TextPainter _rotulo(String valor) =>
      TextPainter(text: TextSpan(text: valor, style: texto), textDirection: TextDirection.ltr)..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final pesos = pesajes.map((p) => p.peso).toList();
    final minimo = pesos.reduce(math.min);
    final maximo = pesos.reduce(math.max);
    final rangoPeso = maximo - minimo == 0 ? 1.0 : maximo - minimo;

    final rotuloMax = _rotulo(formatearPeso(maximo));
    final rotuloMin = _rotulo(formatearPeso(minimo));
    final izquierda = math.max(rotuloMax.width, rotuloMin.width) + 10;
    const arriba = 8.0;
    const derecha = 8.0;
    final abajo = rotuloMin.height + 10;
    final ancho = size.width - izquierda - derecha;
    final alto = size.height - arriba - abajo;

    final inicio = pesajes.first.fecha;
    final totalDias = pesajes.last.fecha.difference(inicio).inDays;
    double x(int i) => totalDias == 0
        ? izquierda + ancho * i / math.max(1, pesajes.length - 1)
        : izquierda + ancho * pesajes[i].fecha.difference(inicio).inDays / totalDias;
    double y(double peso) => arriba + alto - (peso - minimo) / rangoPeso * alto;
    final puntos = [for (var i = 0; i < pesajes.length; i++) Offset(x(i), y(pesos[i]))];

    // Relleno degradado bajo la línea.
    final trazo = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final punto in puntos.skip(1)) {
      trazo.lineTo(punto.dx, punto.dy);
    }
    final area = Path.from(trazo)
      ..lineTo(puntos.last.dx, arriba + alto)
      ..lineTo(puntos.first.dx, arriba + alto)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [linea.withValues(alpha: 0.22), linea.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, arriba, size.width, alto)),
    );

    // Guías por encima del relleno, para que se vean continuas.
    final pincelGuia = Paint()
      ..color = guia
      ..strokeWidth = 1;
    for (final altura in [arriba, arriba + alto / 2, arriba + alto]) {
      canvas.drawLine(Offset(izquierda, altura), Offset(size.width - derecha, altura), pincelGuia);
    }

    canvas.drawPath(
      trazo,
      Paint()
        ..color = linea
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    for (final punto in puntos) {
      canvas.drawCircle(punto, 3.5, Paint()..color = linea);
    }

    // Escala: peso máximo y mínimo a la izquierda; primera y última fecha abajo.
    rotuloMax.paint(canvas, Offset(0, arriba - rotuloMax.height / 2));
    rotuloMin.paint(canvas, Offset(0, arriba + alto - rotuloMin.height / 2));
    final fechaInicio = _rotulo(formatearFecha(inicio));
    final fechaFin = _rotulo(formatearFecha(pesajes.last.fecha));
    fechaInicio.paint(canvas, Offset(izquierda, size.height - fechaInicio.height));
    fechaFin.paint(canvas, Offset(size.width - derecha - fechaFin.width, size.height - fechaFin.height));
  }

  @override
  bool shouldRepaint(_PintorPesos anterior) =>
      anterior.pesajes != pesajes || anterior.linea != linea || anterior.guia != guia;
}

// HU-55: formulario de pesaje. Con [pesaje] edita ese pesaje en lugar de
// registrar uno nuevo. Devuelve true si se guardó.
Future<bool?> abrirRegistroPesaje(
  BuildContext context,
  Animal animal, {
  List<Pesaje> historial = const [],
  Pesaje? pesaje,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _RegistroPesaje(
    animal: animal,
    // Al editar, el propio pesaje no cuenta para "fecha repetida" ni para comparar.
    historial: [for (final p in historial) if (p.id != pesaje?.id) p],
    pesaje: pesaje,
  ),
);

// Pesaje inmediatamente anterior a la fecha indicada (o null si no hay).
Pesaje? pesajeAnterior(List<Pesaje> historial, DateTime fecha) {
  final anteriores = historial.where((p) => p.fecha.isBefore(fecha)).toList()
    ..sort((a, b) => b.fecha.compareTo(a.fecha));
  return anteriores.isEmpty ? null : anteriores.first;
}

// Un cambio de más del 30 % respecto del pesaje anterior suele ser un error
// de tipeo: se pide confirmación, pero no se bloquea.
bool esCambioBrusco(double anterior, double nuevo) => anterior > 0 && (nuevo - anterior).abs() / anterior > 0.3;

bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

// Mismas reglas que el servidor: obligatorio, mayor que 0 y hasta 1500 kg.
String? validarPesoPesaje(String? valor) {
  if (valor == null || valor.trim().isEmpty) return 'El peso es obligatorio';
  return validarPeso(valor);
}

class _RegistroPesaje extends StatefulWidget {
  const _RegistroPesaje({required this.animal, required this.historial, this.pesaje});

  final Animal animal;
  final List<Pesaje> historial;
  // null: pesaje nuevo; si no, el que se corrige.
  final Pesaje? pesaje;

  @override
  State<_RegistroPesaje> createState() => _RegistroPesajeState();
}

class _RegistroPesajeState extends State<_RegistroPesaje> {
  final _api = ApiClient();
  late final _peso = TextEditingController(text: widget.pesaje == null ? '' : _textoPeso(widget.pesaje!.peso));
  late final _observacion = TextEditingController(text: widget.pesaje?.observacion ?? '');
  late DateTime? _fecha = widget.pesaje?.fecha ?? fechaDeHoy();

  bool get _editando => widget.pesaje != null;

  static String _textoPeso(double peso) =>
      peso == peso.roundToDouble() ? peso.toStringAsFixed(0) : peso.toString().replaceAll('.', ',');
  Map<String, String> _errores = {};
  String? _errorServidor;
  bool _guardando = false;

  @override
  void dispose() {
    _peso.dispose();
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _errores = {
        'peso': ?validarPesoPesaje(_peso.text),
        'fecha': ?validarFechaBaja(_fecha, widget.animal.fechaNacimiento, obligatoria: 'La fecha es obligatoria'),
        'observacion': ?validarLargo(_observacion.text, 500),
      };
      final cambioLaFecha = !_editando || !_mismoDia(widget.pesaje!.fecha, _fecha!);
      if (!_errores.containsKey('fecha') && cambioLaFecha && widget.historial.any((p) => _mismoDia(p.fecha, _fecha!))) {
        _errores['fecha'] = 'Ya hay un pesaje en esa fecha';
      }
      _errorServidor = null;
    });
    if (_errores.isNotEmpty) return;

    final anterior = pesajeAnterior(widget.historial, _fecha!);
    final nuevo = leerPeso(_peso.text)!;
    if (anterior != null && esCambioBrusco(anterior.peso, nuevo) && !await _confirmarCambioBrusco(anterior, nuevo)) {
      return;
    }

    setState(() => _guardando = true);
    try {
      final nota = _observacion.text.trim();
      if (_editando) {
        await _api.editarPesaje(
          widget.animal.id,
          widget.pesaje!.id,
          peso: nuevo,
          fecha: _fecha!,
          observacion: nota.isEmpty ? null : nota,
        );
      } else {
        await _api.registrarPesaje(
          widget.animal.id,
          peso: nuevo,
          fecha: _fecha!,
          observacion: nota.isEmpty ? null : nota,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorServidor = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _errorServidor = 'No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<bool> _confirmarCambioBrusco(Pesaje anterior, double nuevo) async {
    final porcentaje = ((nuevo - anterior.peso) / anterior.peso * 100).round();
    final respuesta = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.tertiary, size: 32),
        title: const Text('El peso cambió mucho'),
        content: Text(
          'El pesaje anterior (${formatearFecha(anterior.fecha)}) fue de ${formatearPeso(anterior.peso)}. '
          'El nuevo es de ${formatearPeso(nuevo)} (${porcentaje > 0 ? '+' : ''}$porcentaje %). '
          '¿Está bien el dato?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Revisar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, guardar')),
        ],
      ),
    );
    return respuesta ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget etiqueta(String texto) =>
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(texto, style: tema.textTheme.labelLarge));

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.monitor_weight_outlined, color: tema.colorScheme.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_editando ? 'Editar pesaje' : 'Registrar pesaje', style: tema.textTheme.titleLarge)),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.animal.arete}${widget.animal.nombre == null ? '' : ' · ${widget.animal.nombre}'}'
                ' · peso actual ${formatearPeso(widget.animal.peso)}',
                style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              etiqueta('Peso (kg) *'),
              TextField(
                controller: _peso,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(hintText: 'Ej. 345,5', suffixText: 'kg', errorText: _errores['peso']),
              ),
              const SizedBox(height: 16),
              etiqueta('Fecha del pesaje *'),
              CampoFecha(
                valor: _fecha,
                titulo: 'Fecha del pesaje',
                primeraFecha: widget.animal.fechaNacimiento,
                errorText: _errores['fecha'],
                onChanged: (f) => setState(() {
                  _fecha = f;
                  _errores.remove('fecha');
                }),
              ),
              const SizedBox(height: 16),
              etiqueta('Observación'),
              TextField(
                controller: _observacion,
                maxLines: 2,
                decoration: InputDecoration(hintText: 'Ej. balanza del corral 2', errorText: _errores['observacion']),
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
                        : Text(_editando ? 'Guardar cambios' : 'Guardar pesaje'),
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
