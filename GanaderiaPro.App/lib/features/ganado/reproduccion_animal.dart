import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../core/permisos.dart';
import '../../core/reproduccion.dart';
import '../../core/sesion_actual.dart';
import '../../core/validaciones_animal.dart';
import '../../core/widgets/componentes.dart';

// HU-56: preñez y parto en la ficha de una hembra.
class TarjetaReproduccion extends StatefulWidget {
  const TarjetaReproduccion({super.key, required this.animal});

  final Animal animal;

  @override
  State<TarjetaReproduccion> createState() => _TarjetaReproduccionState();
}

class _TarjetaReproduccionState extends State<TarjetaReproduccion> {
  final _api = ApiClient();
  late Future<List<Prenez>> _futuro = _api.listarPreneces(widget.animal.id);

  // Solo hembras activas y roles con escritura en Reproducción (HU-34).
  bool get _puedeEditar => widget.animal.activo && SesionActual.instancia.puedeEditar(Modulos.reproduccion);

  void _recargar(String mensaje) {
    if (!mounted) return;
    setState(() {
      _futuro = _api.listarPreneces(widget.animal.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _registrarServicio(List<Prenez> preneces) async {
    final ultimoParto = preneces.map((p) => p.fechaParto).whereType<DateTime>().fold<DateTime?>(
      null,
      (max, f) => max == null || f.isAfter(max) ? f : max,
    );
    final datos = await _pedirFecha(
      titulo: 'Registrar servicio',
      etiqueta: 'Fecha de servicio',
      boton: 'Registrar servicio',
      primeraFecha: ultimoParto ?? widget.animal.fechaNacimiento,
      conObservacion: true,
      ayuda: 'El parto probable se calcula sumando 283 días al servicio.',
    );
    if (datos == null) return;
    await _guardar(
      () => _api.registrarServicio(widget.animal.id, fecha: datos.$1, observacion: datos.$2),
      'Servicio registrado.',
    );
  }

  Future<void> _registrarParto(Prenez prenez) async {
    final datos = await _pedirFecha(
      titulo: 'Registrar parto',
      etiqueta: 'Fecha del parto',
      boton: 'Registrar parto',
      primeraFecha: prenez.fechaServicio,
      ayuda: 'Al registrar el parto, la preñez se cierra.',
    );
    if (datos == null) return;
    await _guardar(() => _api.registrarParto(widget.animal.id, prenez.id, fecha: datos.$1), 'Parto registrado.');
  }

  Future<void> _guardar(Future<void> Function() accion, String mensaje) async {
    try {
      await accion();
      _recargar(mensaje);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
      }
    }
  }

  // Devuelve la fecha elegida y la observación, o null si se cancela.
  Future<(DateTime, String?)?> _pedirFecha({
    required String titulo,
    required String etiqueta,
    required String boton,
    required String ayuda,
    DateTime? primeraFecha,
    bool conObservacion = false,
  }) {
    DateTime? fecha = fechaDeHoy();
    String? error;
    final observacion = TextEditingController();
    return showDialog<(DateTime, String?)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogo) => AlertDialog(
          title: Text(titulo),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ayuda, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Text(etiqueta, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                CampoFecha(
                  valor: fecha,
                  titulo: etiqueta,
                  primeraFecha: primeraFecha,
                  errorText: error,
                  onChanged: (f) => setDialogo(() {
                    fecha = f;
                    error = null;
                  }),
                ),
                if (conObservacion) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: observacion,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: 'Observación (opcional)'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (fecha == null) {
                  setDialogo(() => error = 'Elegí la fecha');
                  return;
                }
                final texto = observacion.text.trim();
                Navigator.of(context).pop((fecha!, texto.isEmpty ? null : texto));
              },
              child: Text(boton),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<List<Prenez>>(
          future: _futuro,
          builder: (context, snapshot) {
            final cargado = snapshot.connectionState == ConnectionState.done && !snapshot.hasError;
            final preneces = cargado ? snapshot.data! : const <Prenez>[];
            final abierta = preneces.where((p) => p.abierta).firstOrNull;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Text('Reproducción', style: tema.textTheme.titleMedium),
                    if (_puedeEditar && cargado)
                      abierta == null
                          ? FilledButton.icon(
                              onPressed: () => _registrarServicio(preneces),
                              icon: const Icon(Icons.favorite_border, size: 18),
                              label: const Text('Registrar servicio'),
                            )
                          : FilledButton.icon(
                              onPressed: () => _registrarParto(abierta),
                              icon: const Icon(Icons.child_friendly_outlined, size: 18),
                              label: const Text('Registrar parto'),
                            ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                else if (snapshot.hasError)
                  Text(
                    'No se pudo cargar la reproducción.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error),
                  )
                else ...[
                  if (abierta != null) _EstadoPrenada(prenez: abierta),
                  if (preneces.isEmpty)
                    Text(
                      'Sin servicios registrados.',
                      style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                  for (final p in preneces.where((p) => !p.abierta)) _FilaPrenez(prenez: p),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// Aviso destacado mientras la hembra está preñada.
class _EstadoPrenada extends StatelessWidget {
  const _EstadoPrenada({required this.prenez});

  final Prenez prenez;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.pregnant_woman, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preñada', style: tema.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'Parto probable ${formatearFecha(prenez.fechaProbableParto)} '
                  '(${describirParto(prenez.fechaProbableParto, fechaDeHoy())}) · '
                  'servicio ${formatearFecha(prenez.fechaServicio)}',
                  style: tema.textTheme.bodyMedium,
                ),
                if (prenez.observacion != null) ...[
                  const SizedBox(height: 2),
                  Text(prenez.observacion!, style: tema.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Preñez anterior, ya cerrada con su parto.
class _FilaPrenez extends StatelessWidget {
  const _FilaPrenez({required this.prenez});

  final Prenez prenez;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tema.colorScheme.outlineVariant))),
      child: Row(
        children: [
          Icon(Icons.child_friendly_outlined, size: 20, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Parto ${formatearFecha(prenez.fechaParto!)} · servicio ${formatearFecha(prenez.fechaServicio)}',
              style: tema.textTheme.bodyMedium,
            ),
          ),
          if (prenez.observacion != null)
            Flexible(
              child: Text(
                prenez.observacion!,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
