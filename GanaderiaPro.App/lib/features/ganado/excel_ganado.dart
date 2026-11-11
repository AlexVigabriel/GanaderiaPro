import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/archivos.dart';
import '../../core/permisos.dart';
import '../../core/sesion_actual.dart';

// Filtros vigentes del listado, para exportar lo mismo que se ve (HU-44).
typedef FiltrosListado = ({String? busqueda, String? estado, String? sexo, String? raza, String? categoria});

// HU-43.1, HU-43.2 y HU-44: menú «Excel» del listado de ganado. Muestra solo
// las opciones que el rol tiene permitidas.
class BotonExcel extends StatelessWidget {
  const BotonExcel({super.key, required this.filtros, required this.onImportado});

  final FiltrosListado Function() filtros;
  final VoidCallback onImportado;

  static bool get visible =>
      SesionActual.instancia.puedeVer(Modulos.exportarExcel) || SesionActual.instancia.puedeEditar(Modulos.importarExcel);

  @override
  Widget build(BuildContext context) {
    final sesion = SesionActual.instancia;
    final puedeExportar = sesion.puedeVer(Modulos.exportarExcel);
    final puedeImportar = sesion.puedeEditar(Modulos.importarExcel);

    return PopupMenuButton<String>(
      tooltip: 'Excel',
      onSelected: (opcion) => switch (opcion) {
        'exportar' => _exportar(context),
        'plantilla' => _plantilla(context),
        _ => _importar(context),
      },
      itemBuilder: (_) => [
        if (puedeExportar)
          const PopupMenuItem(
            value: 'exportar',
            child: ListTile(leading: Icon(Icons.download_outlined), title: Text('Exportar a Excel')),
          ),
        if (puedeImportar) ...[
          const PopupMenuItem(
            value: 'plantilla',
            child: ListTile(leading: Icon(Icons.description_outlined), title: Text('Descargar plantilla')),
          ),
          const PopupMenuItem(
            value: 'importar',
            child: ListTile(leading: Icon(Icons.upload_file_outlined), title: Text('Importar desde Excel')),
          ),
        ],
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.table_view_outlined), label: const Text('Excel')),
      ),
    );
  }

  static void _avisar(BuildContext context, String mensaje) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  Future<void> _exportar(BuildContext context) async {
    final f = filtros();
    try {
      final bytes = await ApiClient().exportarGanadoExcel(
        busqueda: f.busqueda,
        estado: f.estado,
        sexo: f.sexo,
        raza: f.raza,
        categoria: f.categoria,
      );
      final hoy = DateTime.now();
      String dos(int n) => n.toString().padLeft(2, '0');
      final nombre = 'ganado_${hoy.year}-${dos(hoy.month)}-${dos(hoy.day)}.xlsx';
      if (await ArchivosLocales.instancia.guardar(nombre, bytes) && context.mounted) {
        _avisar(context, 'Se descargó $nombre.');
      }
    } on ApiException catch (e) {
      if (context.mounted) _avisar(context, e.mensaje);
    } catch (_) {
      if (context.mounted) _avisar(context, 'No se pudo exportar el archivo.');
    }
  }

  Future<void> _plantilla(BuildContext context) async {
    try {
      final bytes = await ApiClient().descargarPlantillaExcel();
      if (await ArchivosLocales.instancia.guardar('plantilla_ganado.xlsx', bytes) && context.mounted) {
        _avisar(context, 'Se descargó la plantilla. Completala y usá «Importar desde Excel».');
      }
    } on ApiException catch (e) {
      if (context.mounted) _avisar(context, e.mensaje);
    } catch (_) {
      if (context.mounted) _avisar(context, 'No se pudo descargar la plantilla.');
    }
  }

  Future<void> _importar(BuildContext context) async {
    final archivo = await ArchivosLocales.instancia.elegirExcel();
    if (archivo == null || !context.mounted) return;

    final resultado = await showDialog<ResultadoImportacion>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _Importando(nombre: archivo.nombre, bytes: archivo.bytes),
    );
    if (resultado == null || !context.mounted) return;
    if (resultado.importadas > 0) onImportado();
    await showDialog<void>(context: context, builder: (_) => ResumenImportacion(resultado: resultado));
  }
}

// Sube el archivo y cierra con el resultado; si el servidor lo rechaza
// completo (columnas distintas, no es Excel), muestra el motivo.
class _Importando extends StatefulWidget {
  const _Importando({required this.nombre, required this.bytes});

  final String nombre;
  final Uint8List bytes;

  @override
  State<_Importando> createState() => _ImportandoState();
}

class _ImportandoState extends State<_Importando> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _subir();
  }

  Future<void> _subir() async {
    try {
      final resultado = await ApiClient().importarGanadoExcel(widget.bytes, widget.nombre);
      if (mounted) Navigator.of(context).pop(resultado);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo conectar con el servidor.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_error == null ? 'Importando ${widget.nombre}…' : 'No se pudo importar'),
    content: _error == null
        ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
        : Text(_error!),
    actions: [
      if (_error != null) TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
    ],
  );
}

// HU-43.2: «N importadas, M rechazadas» y el motivo de cada fila rechazada.
class ResumenImportacion extends StatelessWidget {
  const ResumenImportacion({super.key, required this.resultado});

  final ResultadoImportacion resultado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      icon: Icon(
        resultado.rechazadas == 0 ? Icons.check_circle_outline : Icons.info_outline,
        color: resultado.rechazadas == 0 ? tema.colorScheme.primary : const Color(0xFFB7791F),
        size: 30,
      ),
      title: Text('${resultado.importadas} importadas, ${resultado.rechazadas} rechazadas'),
      content: SizedBox(
        width: 480,
        child: resultado.detalle.isEmpty
            ? const Text('Todos los animales del archivo se registraron.')
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in resultado.detalle)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Text('Fila ${r.fila}', style: tema.textTheme.labelLarge),
                        title: Text(r.motivo),
                      ),
                  ],
                ),
              ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Listo'))],
    );
  }
}
