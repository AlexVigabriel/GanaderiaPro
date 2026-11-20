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

  // RC-10: si todavía no pasó el plazo, avisa desde cuándo y devuelve true.
  bool _todaviaNo(DateTime desde, String mensaje) {
    if (!desde.isAfter(fechaDeHoy())) return false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$mensaje Se puede desde el ${formatearFecha(desde)}.')));
    return true;
  }

  Future<void> _registrarServicio(List<Prenez> preneces) async {
    // RC-10: tras un parto se esperan 40 días; tras un aborto, 21 (un celo).
    final ultima = preneces.where((p) => p.servicioPosibleDesde != null).fold<Prenez?>(
      null,
      (max, p) => max == null || p.servicioPosibleDesde!.isAfter(max.servicioPosibleDesde!) ? p : max,
    );
    final desde = ultima?.servicioPosibleDesde;
    if (ultima != null &&
        _todaviaNo(
          desde!,
          switch (ultima.estado) {
            'Parto' => 'Después del parto del ${formatearFecha(ultima.fechaParto!)} el útero necesita '
                '${Prenez.esperaTrasParto} días para recuperarse.',
            'Aborto' => 'Después del aborto del ${formatearFecha(ultima.fechaAborto!)} hay que esperar un ciclo '
                'de celo (${Prenez.esperaTrasAborto} días).',
            _ => 'No puede ser anterior al diagnóstico «Vacía».',
          },
        )) {
      return;
    }
    final datos = await _pedirFecha(
      titulo: 'Registrar servicio',
      etiqueta: 'Fecha de servicio',
      boton: 'Registrar servicio',
      primeraFecha: desde ?? widget.animal.fechaNacimiento,
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
    if (_todaviaNo(prenez.partoDesde, 'El parto se registra desde los 260 días del servicio; antes es un aborto.')) {
      return;
    }
    final datos = await _pedirFecha(
      titulo: 'Registrar parto',
      etiqueta: 'Fecha del parto',
      boton: 'Registrar parto',
      primeraFecha: prenez.partoDesde,
      ayuda: 'Al registrar el parto, la preñez se cierra.',
    );
    if (datos == null) return;
    await _guardar(() => _api.registrarParto(widget.animal.id, prenez.id, fecha: datos.$1), 'Parto registrado.');
  }

  // RC-10: «Vacía» cierra la preñez; «Confirmada» la deja abierta.
  Future<void> _registrarDiagnostico(Prenez prenez) async {
    if (_todaviaNo(
      prenez.diagnosticoDesde,
      'La preñez se detecta por ecografía o palpación desde los 30 días del servicio.',
    )) {
      return;
    }
    final datos = await _pedirDiagnostico(prenez);
    if (datos == null) return;
    await _guardar(
      () => _api.registrarDiagnosticoPrenez(widget.animal.id, prenez.id, fecha: datos.$1, resultado: datos.$2),
      datos.$2 == 'Vacia' ? 'Diagnóstico registrado: vacía. La preñez se cerró.' : 'Preñez confirmada.',
    );
  }

  Future<void> _registrarAborto(Prenez prenez) async {
    // RC-10: confirmada después del día 259, no queda ninguna fecha posible de aborto.
    if (prenez.abortoDesde.isAfter(prenez.abortoHasta)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            'Ya no se puede registrar un aborto: el diagnóstico es del ${formatearFecha(prenez.fechaDiagnostico!)} '
            'y el aborto solo se registra hasta los ${Prenez.diasMinimosParto - 1} días del servicio '
            '(${formatearFecha(prenez.abortoHasta)}). Si perdió la cría, registralo como parto.',
          ),
        ));
      return;
    }
    if (_todaviaNo(
      prenez.abortoDesde,
      'Antes de los 42 días del servicio es muerte embrionaria, no aborto: si no quedó preñada, registrá el diagnóstico «Vacía».',
    )) {
      return;
    }
    final datos = await _pedirFecha(
      titulo: 'Registrar aborto',
      etiqueta: 'Fecha del aborto',
      boton: 'Registrar aborto',
      primeraFecha: prenez.abortoDesde,
      ultimaFecha: prenez.abortoHasta,
      ayuda: 'El aborto es la pérdida entre los 42 y los 259 días del servicio. Cierra la preñez: deja de figurar como próxima a parir.',
    );
    if (datos == null) return;
    await _guardar(
      () => _api.registrarAborto(widget.animal.id, prenez.id, fecha: datos.$1),
      'Aborto registrado. La preñez se cerró.',
    );
  }

  Future<(DateTime, String)?> _pedirDiagnostico(Prenez prenez) {
    DateTime? fecha = fechaDeHoy();
    String? resultado;
    String? errorFecha;
    String? errorResultado;
    return showDialog<(DateTime, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogo) {
          final tema = Theme.of(context);
          return AlertDialog(
            title: const Text('Diagnóstico de preñez'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resultado de la palpación o ecografía. «Vacía» cierra la preñez.',
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text('Resultado', style: tema.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'Confirmada', label: Text('Confirmada')),
                      ButtonSegment(value: 'Vacia', label: Text('Vacía')),
                    ],
                    selected: {?resultado},
                    onSelectionChanged: (s) => setDialogo(() {
                      resultado = s.firstOrNull;
                      errorResultado = null;
                    }),
                  ),
                  if (errorResultado != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        errorResultado!,
                        style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Fecha del diagnóstico', style: tema.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  CampoFecha(
                    valor: fecha,
                    titulo: 'Fecha del diagnóstico',
                    primeraFecha: prenez.diagnosticoDesde,
                    errorText: errorFecha,
                    onChanged: (f) => setDialogo(() {
                      fecha = f;
                      errorFecha = null;
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (fecha == null || resultado == null) {
                    setDialogo(() {
                      if (fecha == null) errorFecha = 'Elegí la fecha';
                      if (resultado == null) errorResultado = 'Elegí el resultado';
                    });
                    return;
                  }
                  Navigator.of(context).pop((fecha!, resultado!));
                },
                child: const Text('Registrar diagnóstico'),
              ),
            ],
          );
        },
      ),
    );
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
    // Por defecto, hoy. Si es anterior a hoy, la fecha sugerida es esa.
    DateTime? ultimaFecha,
    bool conObservacion = false,
  }) {
    final hoy = fechaDeHoy();
    DateTime? fecha = ultimaFecha != null && ultimaFecha.isBefore(hoy) ? ultimaFecha : hoy;
    String? error;
    String? errorObservacion;
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
                  ultimaFecha: ultimaFecha != null && ultimaFecha.isBefore(hoy) ? ultimaFecha : null,
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
                    decoration: InputDecoration(labelText: 'Observación (opcional)', errorText: errorObservacion),
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
                // RC-07: la observación tiene que describir algo.
                final problema = validarObservacion(observacion.text);
                if (problema != null) {
                  setDialogo(() => errorObservacion = problema);
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
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (abierta.diagnostico == null)
                                  OutlinedButton.icon(
                                    onPressed: () => _registrarDiagnostico(abierta),
                                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                                    label: const Text('Diagnóstico de preñez'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => _registrarAborto(abierta),
                                  icon: const Icon(Icons.heart_broken_outlined, size: 18),
                                  label: const Text('Registrar aborto'),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _registrarParto(abierta),
                                  icon: const Icon(Icons.child_friendly_outlined, size: 18),
                                  label: const Text('Registrar parto'),
                                ),
                              ],
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
                const SizedBox(height: 2),
                Text(
                  prenez.confirmada
                      ? 'Preñez confirmada el ${formatearFecha(prenez.fechaDiagnostico!)}'
                      : 'Sin diagnóstico de preñez',
                  style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
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

// Preñez anterior, ya cerrada con su parto, un aborto o el diagnóstico «Vacía» (RC-10).
class _FilaPrenez extends StatelessWidget {
  const _FilaPrenez({required this.prenez});

  final Prenez prenez;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (icono, cierre) = switch (prenez.estado) {
      'Aborto' => (Icons.heart_broken_outlined, 'Aborto'),
      'Vacia' => (Icons.fact_check_outlined, 'Vacía'),
      _ => (Icons.child_friendly_outlined, 'Parto'),
    };
    final fechaCierre = prenez.fechaCierre;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tema.colorScheme.outlineVariant))),
      child: Row(
        children: [
          Icon(icono, size: 20, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$cierre${fechaCierre == null ? '' : ' ${formatearFecha(fechaCierre)}'} · '
              'servicio ${formatearFecha(prenez.fechaServicio)}',
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
