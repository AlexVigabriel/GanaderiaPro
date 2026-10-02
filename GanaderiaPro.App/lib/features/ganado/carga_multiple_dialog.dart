import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/catalogos.dart';
import '../../core/validaciones_animal.dart';
import '../../core/widgets/componentes.dart';

// HU-66: abre la carga múltiple de animales. Devuelve cuántos animales se
// registraron, o null si no se registró ninguno.
Future<int?> abrirCargaMultiple(BuildContext context) {
  final angosto = MediaQuery.sizeOf(context).width < 720;
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => angosto
        ? const Dialog.fullscreen(child: CargaMultipleAnimales())
        : Dialog(
            insetPadding: const EdgeInsets.all(24),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: const CargaMultipleAnimales(),
            ),
          ),
  );
}

class CargaMultipleAnimales extends StatefulWidget {
  const CargaMultipleAnimales({super.key});

  @override
  State<CargaMultipleAnimales> createState() => _CargaMultipleAnimalesState();
}

class _FilaCarga {
  _FilaCarga({this.sexo, this.raza, this.nacimiento});

  final clave = UniqueKey();
  final arete = TextEditingController();
  final nombre = TextEditingController();
  final pesoNacimiento = TextEditingController();
  final peso = TextEditingController();
  final observaciones = TextEditingController();
  String? sexo;
  String? raza;
  String? color;
  DateTime? nacimiento;
  bool detalleAbierto = false;
  Map<String, String> errores = {};
  String? errorServidor;

  // El arete queda vacío a propósito: no se puede repetir (RN-01).
  _FilaCarga copia() => _FilaCarga(sexo: sexo, raza: raza, nacimiento: nacimiento)
    ..nombre.text = nombre.text
    ..pesoNacimiento.text = pesoNacimiento.text
    ..peso.text = peso.text
    ..observaciones.text = observaciones.text
    ..color = color
    ..detalleAbierto = detalleAbierto;

  bool get vacia => [arete, nombre, pesoNacimiento, peso, observaciones].every((c) => c.text.trim().isEmpty);

  DatosAnimal aDatos() => DatosAnimal(
    arete: normalizarIdentificacion(arete.text),
    sexo: sexo!,
    raza: raza!,
    nombre: _texto(nombre),
    fechaNacimiento: nacimiento,
    pesoNacimiento: leerPeso(pesoNacimiento.text),
    peso: leerPeso(peso.text),
    color: color,
    observaciones: _texto(observaciones),
  );

  static String? _texto(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  void dispose() {
    for (final c in [arete, nombre, pesoNacimiento, peso, observaciones]) {
      c.dispose();
    }
  }
}

class _CargaMultipleAnimalesState extends State<CargaMultipleAnimales> {
  static const double _anchoTabla = 1120;
  static const _sexos = ['Hembra', 'Macho'];

  final _api = ApiClient();
  final _filas = <_FilaCarga>[_FilaCarga()];
  String? _sexoDefecto;
  String? _razaDefecto;
  DateTime? _nacimientoDefecto;
  List<String> _resumenErrores = [];
  String? _aviso;
  bool _enviando = false;
  int _registradosTotal = 0;

  @override
  void dispose() {
    for (final fila in _filas) {
      fila.dispose();
    }
    super.dispose();
  }

  int get _aCargar => _filas.where((f) => !f.vacia).length;

  void _cerrar() => Navigator.of(context).pop(_registradosTotal > 0 ? _registradosTotal : null);

  void _agregarFila() => setState(
    () => _filas.add(_FilaCarga(sexo: _sexoDefecto, raza: _razaDefecto, nacimiento: _nacimientoDefecto)),
  );

  void _duplicar(int indice) => setState(() => _filas.insert(indice + 1, _filas[indice].copia()));

  void _eliminar(int indice) {
    setState(() {
      final fila = _filas.removeAt(indice);
      // Se libera después del cuadro, cuando sus campos ya no están en pantalla.
      WidgetsBinding.instance.addPostFrameCallback((_) => fila.dispose());
      if (_filas.isEmpty) _filas.add(_FilaCarga(sexo: _sexoDefecto, raza: _razaDefecto, nacimiento: _nacimientoDefecto));
    });
  }

  // Los valores por defecto también completan las filas que todavía no los tienen.
  void _cambiarDefecto({String? sexo, String? raza, DateTime? nacimiento, bool borrarNacimiento = false}) {
    setState(() {
      if (sexo != null) _sexoDefecto = sexo;
      if (raza != null) _razaDefecto = raza;
      if (nacimiento != null || borrarNacimiento) _nacimientoDefecto = nacimiento;
      for (final fila in _filas) {
        fila.sexo ??= _sexoDefecto;
        fila.raza ??= _razaDefecto;
        fila.nacimiento ??= _nacimientoDefecto;
      }
    });
  }

  // Mismas reglas que el servidor; devuelve true si se puede enviar.
  bool _validar() {
    final resumen = <String>[];
    final aretes = <String, int>{};
    for (final fila in _filas.where((f) => !f.vacia)) {
      final arete = normalizarIdentificacion(fila.arete.text);
      if (arete.isNotEmpty) aretes[arete] = (aretes[arete] ?? 0) + 1;
    }

    for (var i = 0; i < _filas.length; i++) {
      final fila = _filas[i];
      fila.errorServidor = null;
      if (fila.vacia) {
        fila.errores = {};
        continue;
      }

      final errores = <String, String>{
        'arete': ?validarArete(fila.arete.text),
        'sexo': ?validarSexo(fila.sexo),
        'raza': ?validarRaza(fila.raza),
        'nacimiento': ?validarFechaNacimiento(fila.nacimiento),
        'pesoNacimiento': ?validarPesoNacimiento(fila.pesoNacimiento.text),
        'peso': ?validarPeso(fila.peso.text),
        'nombre': ?validarLargo(fila.nombre.text, 100),
        'observaciones': ?validarLargo(fila.observaciones.text, 500),
      };
      if (!errores.containsKey('arete') && (aretes[normalizarIdentificacion(fila.arete.text)] ?? 0) > 1) {
        errores['arete'] = 'Repetido en la tabla';
      }
      // Si el error está en un campo del detalle, se abre para que se vea.
      if (errores.containsKey('peso') || errores.containsKey('observaciones')) fila.detalleAbierto = true;

      fila.errores = errores;
      resumen.addAll(errores.values.map((e) => 'Fila ${i + 1}: $e'));
    }

    if (_aCargar == 0) resumen.add('Completá al menos un animal.');
    setState(() {
      _resumenErrores = resumen;
      _aviso = null;
    });
    return resumen.isEmpty;
  }

  Future<void> _cargar() async {
    if (!_validar()) return;

    final enviadas = _filas.where((f) => !f.vacia).toList();
    setState(() => _enviando = true);

    try {
      final resultado = await _api.registrarLote(enviadas.map((f) => f.aDatos()).toList());
      if (!mounted) return;

      final rechazadas = {for (final r in resultado.rechazados) enviadas[r.fila - 1]: r.motivo};
      _registradosTotal += resultado.registrados;

      if (rechazadas.isEmpty) {
        _cerrar();
        return;
      }

      // Quedan solo las filas rechazadas, marcadas con el motivo del servidor.
      setState(() {
        final registradas = enviadas.where((f) => !rechazadas.containsKey(f)).toList();
        _filas.removeWhere(registradas.contains);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final f in registradas) {
            f.dispose();
          }
        });
        rechazadas.forEach((fila, motivo) => fila.errorServidor = motivo);
        _aviso = resultado.registrados > 0
            ? 'Se registraron ${resultado.registrados} animales. Revisá las filas que quedaron.'
            : null;
        _resumenErrores = [
          for (var i = 0; i < _filas.length; i++)
            if (_filas[i].errorServidor != null) 'Fila ${i + 1}: ${_filas[i].errorServidor}',
        ];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _resumenErrores = [e.mensaje]);
    } catch (_) {
      if (mounted) setState(() => _resumenErrores = ['No se pudo conectar con el servidor.']);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Material(
      color: tema.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Agregar animales', style: tema.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Completá la tabla y abrí el detalle de cada fila para sumar más datos.',
                        style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Cerrar', onPressed: _enviando ? null : _cerrar, icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _valoresPorDefecto(tema),
                  const SizedBox(height: 16),
                  if (_aviso != null) _Mensaje(texto: _aviso!, tipo: _TipoMensaje.exito),
                  if (_resumenErrores.isNotEmpty) _Mensaje(textos: _resumenErrores, tipo: _TipoMensaje.error),
                  LayoutBuilder(
                    builder: (context, restricciones) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: math.max(restricciones.maxWidth, _anchoTabla),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _encabezadoTabla(tema),
                            for (var i = 0; i < _filas.length; i++)
                              _FilaWidget(
                                key: ValueKey(_filas[i].clave),
                                numero: i + 1,
                                fila: _filas[i],
                                sexos: _sexos,
                                onCambio: () => setState(() {}),
                                onDetalle: () => setState(() => _filas[i].detalleAbierto = !_filas[i].detalleAbierto),
                                onDuplicar: () => _duplicar(i),
                                onEliminar: () => _eliminar(i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _enviando ? null : _agregarFila,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar fila'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: tema.colorScheme.outlineVariant))),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 12,
              children: [
                TextButton(onPressed: _enviando ? null : _cerrar, child: const Text('Cancelar')),
                FilledButton(
                  onPressed: _enviando || _aCargar == 0 ? null : _cargar,
                  child: _enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_aCargar == 1 ? 'Cargar 1 animal' : 'Cargar $_aCargar animales'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valoresPorDefecto(ThemeData tema) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Valores por defecto', style: tema.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            'Se aplican a las filas nuevas y a las que todavía no los tienen.',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _sexoDefecto,
                  isExpanded: true,
                  decoration: const InputDecoration(hintText: 'Sexo', isDense: true),
                  items: [for (final s in _sexos) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => _cambiarDefecto(sexo: v),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _razaDefecto,
                  isExpanded: true,
                  decoration: const InputDecoration(hintText: 'Raza', isDense: true),
                  items: [for (final r in razasBovinas) DropdownMenuItem(value: r, child: Text(r))],
                  onChanged: (v) => _cambiarDefecto(raza: v),
                ),
              ),
              SizedBox(
                width: 220,
                child: CampoFecha(
                  valor: _nacimientoDefecto,
                  hint: 'Nacimiento',
                  denso: true,
                  onChanged: (f) => _cambiarDefecto(nacimiento: f, borrarNacimiento: f == null),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _encabezadoTabla(ThemeData tema) {
    final estilo = tema.textTheme.labelMedium?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    Widget columna(String texto, double ancho) => SizedBox(width: ancho, child: Text(texto, style: estilo));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          columna('#', _FilaWidget.anchoNumero),
          columna('Identificación *', _FilaWidget.anchoArete),
          columna('Nombre', _FilaWidget.anchoNombre),
          columna('Sexo *', _FilaWidget.anchoSexo),
          columna('Raza *', _FilaWidget.anchoRaza),
          columna('Nacimiento *', _FilaWidget.anchoFecha),
          columna('Peso al nacer (kg)', _FilaWidget.anchoPeso),
          columna('Acciones', _FilaWidget.anchoAcciones),
        ],
      ),
    );
  }
}

class _FilaWidget extends StatelessWidget {
  const _FilaWidget({
    super.key,
    required this.numero,
    required this.fila,
    required this.sexos,
    required this.onCambio,
    required this.onDetalle,
    required this.onDuplicar,
    required this.onEliminar,
  });

  static const double anchoNumero = 36;
  static const double anchoArete = 150;
  static const double anchoNombre = 160;
  static const double anchoSexo = 140;
  static const double anchoRaza = 170;
  static const double anchoFecha = 180;
  static const double anchoPeso = 140;
  static const double anchoAcciones = 132;
  static const double separacion = 10;

  final int numero;
  final _FilaCarga fila;
  final List<String> sexos;
  final VoidCallback onCambio;
  final VoidCallback onDetalle;
  final VoidCallback onDuplicar;
  final VoidCallback onEliminar;

  Widget _celda(double ancho, Widget hijo) =>
      Padding(padding: const EdgeInsets.only(right: separacion), child: SizedBox(width: ancho - separacion, child: hijo));

  InputDecoration _decoracion(String clave, {String? hint}) =>
      InputDecoration(hintText: hint, isDense: true, errorText: fila.errores[clave], errorMaxLines: 2);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final conError = fila.errores.isNotEmpty || fila.errorServidor != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: conError ? tema.colorScheme.error.withValues(alpha: 0.6) : tema.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: anchoNumero,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('$numero', style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
                ),
              ),
              _celda(
                anchoArete,
                TextField(
                  controller: fila.arete,
                  inputFormatters: formatoIdentificacion,
                  decoration: _decoracion('arete', hint: 'Ej. AR-001'),
                  onChanged: (_) => onCambio(),
                ),
              ),
              _celda(
                anchoNombre,
                TextField(
                  controller: fila.nombre,
                  decoration: _decoracion('nombre', hint: 'Opcional'),
                  onChanged: (_) => onCambio(),
                ),
              ),
              _celda(
                anchoSexo,
                DropdownButtonFormField<String>(
                  initialValue: fila.sexo,
                  isExpanded: true,
                  decoration: _decoracion('sexo', hint: 'Elegir'),
                  items: [for (final s in sexos) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) {
                    fila.sexo = v;
                    onCambio();
                  },
                ),
              ),
              _celda(
                anchoRaza,
                DropdownButtonFormField<String>(
                  initialValue: fila.raza,
                  isExpanded: true,
                  decoration: _decoracion('raza', hint: 'Elegir'),
                  items: [for (final r in opcionesCon(razasBovinas, fila.raza)) DropdownMenuItem(value: r, child: Text(r))],
                  onChanged: (v) {
                    fila.raza = v;
                    onCambio();
                  },
                ),
              ),
              _celda(
                anchoFecha,
                CampoFecha(
                  valor: fila.nacimiento,
                  denso: true,
                  errorText: fila.errores['nacimiento'],
                  onChanged: (f) {
                    fila.nacimiento = f;
                    onCambio();
                  },
                ),
              ),
              _celda(
                anchoPeso,
                TextField(
                  controller: fila.pesoNacimiento,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _decoracion('pesoNacimiento', hint: 'kg'),
                  onChanged: (_) => onCambio(),
                ),
              ),
              SizedBox(
                width: anchoAcciones,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      BotonAccion(
                        icono: Icons.edit_outlined,
                        tooltip: fila.detalleAbierto ? 'Cerrar detalle' : 'Abrir detalle',
                        activo: fila.detalleAbierto,
                        onPressed: onDetalle,
                      ),
                      const SizedBox(width: 8),
                      BotonAccion(icono: Icons.copy_outlined, tooltip: 'Duplicar fila', onPressed: onDuplicar),
                      const SizedBox(width: 8),
                      BotonAccion(
                        icono: Icons.delete_outline,
                        tooltip: 'Eliminar fila',
                        peligro: true,
                        onPressed: onEliminar,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (fila.errorServidor != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: anchoNumero),
              child: Text(
                fila.errorServidor!,
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error),
              ),
            ),
          if (fila.detalleAbierto) _detalle(tema),
        ],
      ),
    );
  }

  Widget _detalle(ThemeData tema) {
    return Container(
      margin: const EdgeInsets.only(top: 12, left: anchoNumero),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: _etiquetado(
              tema,
              'Peso actual (kg)',
              TextField(
                controller: fila.peso,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _decoracion('peso', hint: 'kg'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: _etiquetado(
              tema,
              'Color',
              DropdownButtonFormField<String>(
                initialValue: fila.color,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'Sin especificar', isDense: true),
                items: [for (final c in opcionesCon(coloresPelaje, fila.color)) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => fila.color = v,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _etiquetado(
              tema,
              'Observaciones',
              TextField(
                controller: fila.observaciones,
                maxLines: 2,
                decoration: _decoracion('observaciones', hint: 'Notas sobre el animal'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _etiquetado(ThemeData tema, String etiqueta, Widget campo) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(etiqueta, style: tema.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      campo,
    ],
  );
}

enum _TipoMensaje { exito, error }

class _Mensaje extends StatelessWidget {
  const _Mensaje({this.texto, this.textos = const [], required this.tipo});

  final String? texto;
  final List<String> textos;
  final _TipoMensaje tipo;

  static const int _maximoVisibles = 6;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final error = tipo == _TipoMensaje.error;
    final color = error ? tema.colorScheme.error : tema.colorScheme.primary;
    final lineas = texto != null ? [texto!] : textos;
    final visibles = lineas.take(_maximoVisibles).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error) Text('Revisá la carga', style: tema.textTheme.titleSmall?.copyWith(color: color)),
                for (final linea in visibles) Text(linea, style: tema.textTheme.bodyMedium),
                if (lineas.length > visibles.length)
                  Text('y ${lineas.length - visibles.length} más…', style: tema.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
