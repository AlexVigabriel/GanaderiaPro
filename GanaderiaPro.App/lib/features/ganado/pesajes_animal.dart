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

  Future<void> _registrar() async {
    final registrado = await abrirRegistroPesaje(context, widget.animal);
    if (registrado != true || !mounted) return;
    setState(() => _futuro = _api.listarPesajes(widget.animal.id));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesaje registrado.')));
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
                    onPressed: _registrar,
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
                      SizedBox(height: 120, child: _GraficoPesos(pesajes: pesajes)),
                      const SizedBox(height: 16),
                    ],
                    for (var i = 0; i < pesajes.length; i++)
                      _FilaPesaje(pesaje: pesajes[i], anterior: i + 1 < pesajes.length ? pesajes[i + 1] : null),
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
  const _FilaPesaje({required this.pesaje, required this.anterior});

  final Pesaje pesaje;
  final Pesaje? anterior;

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
        ],
      ),
    );
  }
}

// Línea de evolución del peso, del pesaje más antiguo al más reciente.
class _GraficoPesos extends StatelessWidget {
  const _GraficoPesos({required this.pesajes});

  final List<Pesaje> pesajes;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _PintorPesos(
        pesos: pesajes.reversed.map((p) => p.peso).toList(),
        linea: tema.colorScheme.primary,
        guia: tema.colorScheme.outlineVariant,
      ),
    );
  }
}

class _PintorPesos extends CustomPainter {
  _PintorPesos({required this.pesos, required this.linea, required this.guia});

  final List<double> pesos;
  final Color linea;
  final Color guia;

  @override
  void paint(Canvas canvas, Size size) {
    const margen = 8.0;
    final minimo = pesos.reduce(math.min);
    final maximo = pesos.reduce(math.max);
    final rango = maximo - minimo == 0 ? 1 : maximo - minimo;
    final alto = size.height - margen * 2;
    final paso = (size.width - margen * 2) / (pesos.length - 1);

    Offset punto(int i) => Offset(margen + paso * i, margen + alto - (pesos[i] - minimo) / rango * alto);

    final pincelGuia = Paint()
      ..color = guia
      ..strokeWidth = 1;
    for (final y in [margen, margen + alto / 2, margen + alto]) {
      canvas.drawLine(Offset(margen, y), Offset(size.width - margen, y), pincelGuia);
    }

    final trazo = Path()..moveTo(punto(0).dx, punto(0).dy);
    for (var i = 1; i < pesos.length; i++) {
      trazo.lineTo(punto(i).dx, punto(i).dy);
    }
    final area = Path.from(trazo)
      ..lineTo(punto(pesos.length - 1).dx, margen + alto)
      ..lineTo(punto(0).dx, margen + alto)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [linea.withValues(alpha: 0.22), linea.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      trazo,
      Paint()
        ..color = linea
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < pesos.length; i++) {
      canvas.drawCircle(punto(i), 3.5, Paint()..color = linea);
    }
  }

  @override
  bool shouldRepaint(_PintorPesos anterior) =>
      anterior.pesos != pesos || anterior.linea != linea || anterior.guia != guia;
}

// HU-55: formulario de pesaje. Devuelve true si se registró.
Future<bool?> abrirRegistroPesaje(BuildContext context, Animal animal) =>
    showDialog<bool>(context: context, builder: (_) => _RegistroPesaje(animal: animal));

// Mismas reglas que el servidor: obligatorio, mayor que 0 y hasta 1500 kg.
String? validarPesoPesaje(String? valor) {
  if (valor == null || valor.trim().isEmpty) return 'El peso es obligatorio';
  return validarPeso(valor);
}

class _RegistroPesaje extends StatefulWidget {
  const _RegistroPesaje({required this.animal});

  final Animal animal;

  @override
  State<_RegistroPesaje> createState() => _RegistroPesajeState();
}

class _RegistroPesajeState extends State<_RegistroPesaje> {
  final _api = ApiClient();
  final _peso = TextEditingController();
  final _observacion = TextEditingController();
  DateTime? _fecha = DateTime.now();
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
      _errorServidor = null;
    });
    if (_errores.isNotEmpty) return;

    setState(() => _guardando = true);
    try {
      final nota = _observacion.text.trim();
      await _api.registrarPesaje(
        widget.animal.id,
        peso: leerPeso(_peso.text)!,
        fecha: _fecha!,
        observacion: nota.isEmpty ? null : nota,
      );
      if (mounted) Navigator.of(context).pop(true);
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
                  Expanded(child: Text('Registrar pesaje', style: tema.textTheme.titleLarge)),
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
                        : const Text('Guardar pesaje'),
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
