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
  final _diagnostico = TextEditingController();
  final _medicamento = TextEditingController();
  final _cantidad = TextEditingController();
  final _duracion = TextEditingController();
  final _observacion = TextEditingController();
  late List<Animal> _animales = [?widget.animal];
  String? _unidad;
  DateTime? _inicio = fechaDeHoy();
  Map<String, String> _errores = {};
  String? _errorGeneral;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_diagnostico, _medicamento, _cantidad, _duracion, _observacion]) {
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

  // Las mismas reglas que el servidor (RC-08).
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
      'diagnostico': ?obligatorio(_diagnostico, 100, 'El diagnóstico'),
      'medicamento': ?obligatorio(_medicamento, 150, 'El medicamento'),
      'cantidad': ?validarCantidadDosis(_cantidad.text),
      if (_unidad == null) 'unidad': 'Elegí la unidad',
      if (_inicio == null) 'inicio': 'Elegí la fecha de inicio',
      if (_inicio != null && nacimiento != null && _inicio!.isBefore(nacimiento))
        'inicio': 'No puede ser anterior al nacimiento',
      if (duracion == null || duracion < 1 || duracion > 365) 'duracion': 'De 1 a 365 días',
      'observacion': ?validarObservacion(_observacion.text, 300),
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
          diagnostico: _diagnostico.text.trim(),
          medicamento: _medicamento.text.trim(),
          dosis: armarDosis(_cantidad.text, _unidad!),
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
              TextField(
                controller: _diagnostico,
                maxLength: 100,
                decoration: _decoracion('Diagnóstico', 'diagnostico', hint: 'Ej. Neumonía, Diarrea neonatal'),
              ),
              const SizedBox(height: 4),
              TextField(controller: _medicamento, decoration: _decoracion('Medicamento', 'medicamento')),
              const SizedBox(height: 12),
              // RC-08: la dosis lleva cantidad y unidad.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cantidad,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: _decoracion('Dosis', 'cantidad', hint: 'Ej. 10'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidad,
                      decoration: _decoracion('Unidad', 'unidad'),
                      items: [for (final u in unidadesDosis) DropdownMenuItem(value: u, child: Text(u))],
                      onChanged: _guardando ? null : (u) => setState(() => _unidad = u),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _duracion,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _decoracion('Duración', 'duracion', sufijo: 'días'),
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
                maxLength: 300,
                decoration: _decoracion('Observaciones (opcional)', 'observacion'),
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

// Color de cada estado o resultado.
Color _colorDeEstado(Tratamiento t, ThemeData tema) => switch ((t.estado, t.resultado)) {
  ('EnCurso', _) => const Color(0xFFB7791F),
  (_, 'Recuperado') => const Color(0xFF2F855A),
  (_, 'SinMejoria') => tema.colorScheme.error,
  (_, 'Derivado') => const Color(0xFF2B6CB0),
  _ => tema.colorScheme.onSurfaceVariant,
};

class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      texto,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

// Lista de tratamientos, separada en curso / terminados (RC-09). Tocar uno abre
// su detalle; si ahí se cambió algo, se llama a onCambio.
class ListaTratamientos extends StatelessWidget {
  const ListaTratamientos({
    super.key,
    required this.tratamientos,
    this.puedeEditar = false,
    this.onCambio,
    this.mostrarAnimal = false,
    this.vacio = 'Este animal no tiene tratamientos registrados.',
  });

  final List<Tratamiento> tratamientos;
  final bool puedeEditar;
  final VoidCallback? onCambio;
  final bool mostrarAnimal;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (tratamientos.isEmpty) {
      return Text(vacio, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant));
    }
    final enCurso = tratamientos.where((t) => t.estado == 'EnCurso').toList();
    final terminados = tratamientos.where((t) => t.estado != 'EnCurso').toList();
    final subtitulo = tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant);

    Widget fila(Tratamiento t) => FilaTratamiento(
      tratamiento: t,
      mostrarAnimal: mostrarAnimal,
      onTap: () async {
        if (await abrirDetalleTratamiento(context, t, puedeEditar: puedeEditar)) onCambio?.call();
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (enCurso.isNotEmpty && terminados.isNotEmpty) Text('En curso (${enCurso.length})', style: subtitulo),
        for (final t in enCurso) fila(t),
        if (enCurso.isNotEmpty && terminados.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Terminados (${terminados.length})', style: subtitulo),
        ],
        for (final t in terminados) fila(t),
      ],
    );
  }
}

class FilaTratamiento extends StatelessWidget {
  const FilaTratamiento({super.key, required this.tratamiento, this.onTap, this.mostrarAnimal = false});

  final Tratamiento tratamiento;
  final VoidCallback? onTap;
  final bool mostrarAnimal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final t = tratamiento;
    final suave = tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant);
    final seguimientos = t.seguimientos.length;
    return InkWell(
      onTap: onTap,
      child: Container(
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
                  if (mostrarAnimal) Text(t.animal, style: tema.textTheme.titleSmall),
                  Text('${t.diagnostico} · ${t.medicamento} (${t.dosis})', style: tema.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${formatearFecha(t.fechaInicio)} al ${formatearFecha(t.fechaFin)} · '
                    '${t.duracionDias == 1 ? '1 día' : '${t.duracionDias} días'} · ${t.veterinario}',
                    style: suave,
                  ),
                  Text(
                    [
                      if (t.estado == 'EnCurso') t.avance,
                      if (t.fechaFinalizacion != null) 'Finalizado el ${formatearFecha(t.fechaFinalizacion!)}',
                      seguimientos == 0
                          ? 'Sin seguimientos'
                          : seguimientos == 1
                          ? '1 seguimiento'
                          : '$seguimientos seguimientos',
                    ].join(' · '),
                    style: suave,
                  ),
                  if (t.observacion != null)
                    Text(t.observacion!, style: tema.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Pastilla(texto: t.textoEstado, color: _colorDeEstado(t, tema)),
            if (onTap != null) Icon(Icons.chevron_right, color: tema.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// RC-09: tratamientos de todo el rancho en la pantalla Sanidad, separados en
// «En curso» y «Terminados» (los últimos 50).
class TarjetaTratamientosRancho extends StatefulWidget {
  const TarjetaTratamientosRancho({super.key, required this.puedeEditar});

  final bool puedeEditar;

  @override
  State<TarjetaTratamientosRancho> createState() => _TarjetaTratamientosRanchoState();
}

class _TarjetaTratamientosRanchoState extends State<TarjetaTratamientosRancho> {
  final _api = ApiClient();
  bool _terminados = false;
  late Future<List<Tratamiento>> _futuro = _cargar();

  Future<List<Tratamiento>> _cargar() => _api.listarTratamientosDelRancho(terminados: _terminados);

  void _recargar() => setState(() {
    _futuro = _cargar();
  });

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
                Text('Tratamientos', style: tema.textTheme.titleLarge),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('En curso'), icon: Icon(Icons.timelapse, size: 18)),
                    ButtonSegment(value: true, label: Text('Terminados'), icon: Icon(Icons.task_alt, size: 18)),
                  ],
                  selected: {_terminados},
                  onSelectionChanged: (s) => setState(() {
                    _terminados = s.first;
                    _futuro = _cargar();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Tratamiento>>(
              future: _futuro,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'No se pudieron cargar los tratamientos.',
                          style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error),
                        ),
                      ),
                      TextButton(onPressed: _recargar, child: const Text('Reintentar')),
                    ],
                  );
                }
                return ListaTratamientos(
                  tratamientos: snapshot.data!,
                  puedeEditar: widget.puedeEditar,
                  onCambio: _recargar,
                  mostrarAnimal: true,
                  vacio: _terminados ? 'No hay tratamientos terminados.' : 'No hay tratamientos en curso.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// RC-09: detalle del tratamiento con su avance, sus seguimientos y los botones
// para registrar uno nuevo o finalizarlo. Devuelve true si se cambió algo.
Future<bool> abrirDetalleTratamiento(BuildContext context, Tratamiento tratamiento, {required bool puedeEditar}) async {
  final cambio = await showDialog<bool>(
    context: context,
    builder: (_) => _DetalleTratamiento(tratamiento: tratamiento, puedeEditar: puedeEditar),
  );
  return cambio ?? false;
}

class _DetalleTratamiento extends StatefulWidget {
  const _DetalleTratamiento({required this.tratamiento, required this.puedeEditar});

  final Tratamiento tratamiento;
  final bool puedeEditar;

  @override
  State<_DetalleTratamiento> createState() => _DetalleTratamientoState();
}

class _DetalleTratamientoState extends State<_DetalleTratamiento> {
  late Tratamiento _t = widget.tratamiento;
  bool _cambio = false;

  void _actualizar(Tratamiento nuevo, String mensaje) {
    setState(() {
      _t = nuevo;
      _cambio = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _seguimiento() async {
    final nuevo = await showDialog<Tratamiento>(context: context, builder: (_) => _DialogoSeguimiento(tratamiento: _t));
    if (nuevo != null && mounted) _actualizar(nuevo, 'Seguimiento registrado.');
  }

  Future<void> _finalizar() async {
    final nuevo = await showDialog<Tratamiento>(context: context, builder: (_) => _DialogoFinalizar(tratamiento: _t));
    if (nuevo != null && mounted) _actualizar(nuevo, 'Tratamiento finalizado.');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final t = _t;
    final suave = tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant);
    final hoy = fechaDeHoy();
    final yaHoy = t.seguimientos.any((s) => DateUtils.isSameDay(s.fecha, hoy));
    // Hay al menos un día sin seguimiento entre el inicio y hoy (o el último día).
    final ultimo = t.ultimoDiaSeguimiento(hoy);
    final diasPosibles = ultimo.difference(t.fechaInicio).inDays + 1;
    final puedeSeguir = widget.puedeEditar && !t.finalizado && t.seguimientos.length < diasPosibles;

    return AlertDialog(
      title: Text('${t.diagnostico} · ${t.arete}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Pastilla(texto: t.textoEstado, color: _colorDeEstado(t, tema)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: t.estado == 'EnCurso'
                        ? Text(t.avance, style: tema.textTheme.titleMedium)
                        : Text(
                            t.fechaFinalizacion != null
                                ? 'Finalizado el ${formatearFecha(t.fechaFinalizacion!)}'
                                : 'Pasó el último día sin cargar el resultado',
                            style: tema.textTheme.bodyMedium,
                          ),
                  ),
                ],
              ),
              if (t.estado == 'EnCurso') ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: t.diaActual / t.duracionDias, minHeight: 6, borderRadius: BorderRadius.circular(3)),
              ],
              const SizedBox(height: 14),
              Text('${t.medicamento} · ${t.dosis}', style: tema.textTheme.bodyLarge),
              Text(
                '${formatearFecha(t.fechaInicio)} al ${formatearFecha(t.fechaFin)} · '
                '${t.duracionDias == 1 ? '1 día' : '${t.duracionDias} días'} · ${t.veterinario}',
                style: suave,
              ),
              if (t.observacion != null) ...[
                const SizedBox(height: 4),
                Text(t.observacion!, style: tema.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 18),
              Text('Seguimiento diario', style: tema.textTheme.titleSmall),
              const SizedBox(height: 6),
              if (t.seguimientos.isEmpty)
                Text('Todavía no hay seguimientos.', style: suave)
              else
                for (final s in t.seguimientos.reversed) _FilaSeguimiento(seguimiento: s, tratamiento: t),
              if (puedeSeguir && yaHoy) ...[
                const SizedBox(height: 6),
                Text('Hoy ya tiene seguimiento; podés cargar un día anterior que falte.', style: suave),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(_cambio), child: const Text('Cerrar')),
        if (widget.puedeEditar && !t.finalizado)
          OutlinedButton.icon(
            onPressed: _finalizar,
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Finalizar tratamiento'),
          ),
        if (puedeSeguir)
          FilledButton.icon(
            onPressed: _seguimiento,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Registrar seguimiento'),
          ),
      ],
    );
  }
}

class _FilaSeguimiento extends StatelessWidget {
  const _FilaSeguimiento({required this.seguimiento, required this.tratamiento});

  final SeguimientoTratamiento seguimiento;
  final Tratamiento tratamiento;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final s = seguimiento;
    final dia = s.fecha.difference(tratamiento.fechaInicio).inDays + 1;
    final (icono, color) = switch (s.evolucion) {
      'Mejora' => (Icons.trending_up, const Color(0xFF2F855A)),
      'Empeora' => (Icons.trending_down, tema.colorScheme.error),
      _ => (Icons.trending_flat, tema.colorScheme.onSurfaceVariant),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Día $dia · ${formatearFecha(s.fecha)} · ${nombresEvolucion[s.evolucion] ?? s.evolucion}',
                  style: tema.textTheme.bodyMedium,
                ),
                if (s.nota != null) Text(s.nota!, style: tema.textTheme.bodySmall),
                Text(s.usuario, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// RC-09: un seguimiento por día, entre el inicio y hoy (sin pasar el último día).
class _DialogoSeguimiento extends StatefulWidget {
  const _DialogoSeguimiento({required this.tratamiento});

  final Tratamiento tratamiento;

  @override
  State<_DialogoSeguimiento> createState() => _DialogoSeguimientoState();
}

class _DialogoSeguimientoState extends State<_DialogoSeguimiento> {
  final _nota = TextEditingController();
  late DateTime? _fecha = _sugerida();
  String? _evolucion;
  Map<String, String> _errores = {};
  String? _errorGeneral;
  bool _guardando = false;

  // El último día posible que todavía no tiene seguimiento.
  DateTime? _sugerida() {
    final t = widget.tratamiento;
    for (var f = t.ultimoDiaSeguimiento(fechaDeHoy()); !f.isBefore(t.fechaInicio); f = f.subtract(const Duration(days: 1))) {
      if (!_tieneSeguimiento(f)) return f;
    }
    return null;
  }

  bool _tieneSeguimiento(DateTime f) => widget.tratamiento.seguimientos.any((s) => DateUtils.isSameDay(s.fecha, f));

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final errores = {
      if (_fecha == null) 'fecha': 'Elegí la fecha',
      if (_fecha != null && _tieneSeguimiento(_fecha!)) 'fecha': 'Ese día ya tiene seguimiento',
      if (_evolucion == null) 'evolucion': 'Elegí cómo evolucionó',
      'nota': ?validarObservacion(_nota.text, 300),
    };
    setState(() {
      _errores = errores;
      _errorGeneral = null;
    });
    if (errores.isNotEmpty) return;

    setState(() => _guardando = true);
    try {
      final nota = _nota.text.trim();
      final nuevo = await ApiClient().registrarSeguimiento(
        widget.tratamiento,
        fecha: _fecha!,
        evolucion: _evolucion!,
        nota: nota.isEmpty ? null : nota,
      );
      if (mounted) Navigator.of(context).pop(nuevo);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorGeneral = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _errorGeneral = 'No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final t = widget.tratamiento;
    return AlertDialog(
      title: const Text('Registrar seguimiento'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorGeneral != null) ...[
                Text(_errorGeneral!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
                const SizedBox(height: 12),
              ],
              Text('${t.diagnostico} · ${t.medicamento} (${t.dosis})', style: tema.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Text('Fecha', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              CampoFecha(
                valor: _fecha,
                titulo: 'Fecha del seguimiento',
                primeraFecha: t.fechaInicio,
                ultimaFecha: t.ultimoDiaSeguimiento(fechaDeHoy()),
                errorText: _errores['fecha'],
                onChanged: (f) => setState(() => _fecha = f),
              ),
              const SizedBox(height: 16),
              Text('Evolución', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                segments: [
                  for (final e in nombresEvolucion.entries) ButtonSegment(value: e.key, label: Text(e.value)),
                ],
                selected: {?_evolucion},
                onSelectionChanged: (s) => setState(() => _evolucion = s.firstOrNull),
              ),
              if (_errores['evolucion'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _errores['evolucion']!,
                    style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _nota,
                maxLines: 2,
                maxLength: 300,
                decoration: InputDecoration(labelText: 'Nota (opcional)', errorText: _errores['nota']),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar seguimiento'),
        ),
      ],
    );
  }
}

// RC-09: finalizar con un resultado, aunque no haya llegado al último día.
class _DialogoFinalizar extends StatefulWidget {
  const _DialogoFinalizar({required this.tratamiento});

  final Tratamiento tratamiento;

  @override
  State<_DialogoFinalizar> createState() => _DialogoFinalizarState();
}

class _DialogoFinalizarState extends State<_DialogoFinalizar> {
  DateTime? _fecha = fechaDeHoy();
  String? _resultado;
  Map<String, String> _errores = {};
  String? _errorGeneral;
  bool _guardando = false;

  // No antes del último seguimiento.
  DateTime get _minima {
    final t = widget.tratamiento;
    return t.seguimientos.isEmpty ? t.fechaInicio : t.seguimientos.map((s) => s.fecha).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Future<void> _guardar() async {
    final errores = {
      if (_fecha == null) 'fecha': 'Elegí la fecha',
      if (_resultado == null) 'resultado': 'Elegí el resultado',
    };
    setState(() {
      _errores = errores;
      _errorGeneral = null;
    });
    if (errores.isNotEmpty) return;

    setState(() => _guardando = true);
    try {
      final nuevo = await ApiClient().finalizarTratamiento(widget.tratamiento, fecha: _fecha!, resultado: _resultado!);
      if (mounted) Navigator.of(context).pop(nuevo);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorGeneral = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _errorGeneral = 'No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final t = widget.tratamiento;
    return AlertDialog(
      title: const Text('Finalizar tratamiento'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorGeneral != null) ...[
              Text(_errorGeneral!, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error)),
              const SizedBox(height: 12),
            ],
            Text(
              t.estado == 'EnCurso'
                  ? '${t.diagnostico}: va por el ${t.avance.toLowerCase()}. Se puede finalizar antes del último día.'
                  : '${t.diagnostico}: cargá cómo terminó.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Resultado', style: tema.textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: [
                for (final e in nombresResultado.entries) ButtonSegment(value: e.key, label: Text(e.value)),
              ],
              selected: {?_resultado},
              onSelectionChanged: (s) => setState(() => _resultado = s.firstOrNull),
            ),
            if (_errores['resultado'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _errores['resultado']!,
                  style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            Text('Fecha de finalización', style: tema.textTheme.labelLarge),
            const SizedBox(height: 6),
            CampoFecha(
              valor: _fecha,
              titulo: 'Fecha de finalización',
              primeraFecha: _minima,
              errorText: _errores['fecha'],
              onChanged: (f) => setState(() => _fecha = f),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Finalizar'),
        ),
      ],
    );
  }
}
