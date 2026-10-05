import 'package:flutter/material.dart';

import '../../core/animal.dart';
import '../../core/api_client.dart';
import '../../core/formato.dart';
import '../../core/sanidad.dart';
import '../../core/widgets/componentes.dart';
import 'registro_vacunacion_dialog.dart';

// Una vacunación en una lista: vacuna, dosis, fechas y, si corresponde, el
// animal y los botones para corregirla.
class FilaVacunacion extends StatelessWidget {
  const FilaVacunacion({
    super.key,
    required this.vacunacion,
    this.mostrarAnimal = false,
    this.onEditar,
    this.onEliminar,
  });

  final Vacunacion vacunacion;
  final bool mostrarAnimal;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final suave = tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant);
    final v = vacunacion;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: tema.colorScheme.outlineVariant))),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tema.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.vaccines_outlined, size: 20, color: tema.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mostrarAnimal ? '${v.animal} — ${v.vacuna}' : v.vacuna,
                  style: tema.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    '${formatearFecha(v.fechaAplicacion)} · ${v.dosis}',
                    if (v.fechaProximaDosis != null) 'próxima dosis ${formatearFecha(v.fechaProximaDosis!)}',
                    if (v.veterinario.isNotEmpty) v.veterinario,
                  ].join(' · '),
                  style: suave,
                ),
                if (v.observacion != null) Text(v.observacion!, style: suave),
              ],
            ),
          ),
          if (onEditar != null) ...[
            BotonAccion(icono: Icons.edit_outlined, tooltip: 'Editar vacunación', onPressed: onEditar),
            const SizedBox(width: 8),
          ],
          if (onEliminar != null)
            BotonAccion(icono: Icons.delete_outline, tooltip: 'Eliminar vacunación', peligro: true, onPressed: onEliminar),
        ],
      ),
    );
  }
}

// Pide confirmación y elimina una vacunación cargada por error. Devuelve
// true si se eliminó.
Future<bool> eliminarVacunacion(BuildContext context, Vacunacion v) async {
  final tema = Theme.of(context);
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Eliminar esta vacunación?'),
      content: Text('${v.vacuna} aplicada a ${v.animal} el ${formatearFecha(v.fechaAplicacion)}.'),
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
  if (confirmado != true || !context.mounted) return false;

  try {
    await ApiClient().eliminarVacunacion(v.id);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
    }
  }
  return false;
}

// HU-26: historial sanitario en la ficha del animal.
class TarjetaHistorialSanitario extends StatefulWidget {
  const TarjetaHistorialSanitario({super.key, required this.animal});

  final Animal animal;

  @override
  State<TarjetaHistorialSanitario> createState() => _TarjetaHistorialSanitarioState();
}

class _TarjetaHistorialSanitarioState extends State<TarjetaHistorialSanitario> {
  final _api = ApiClient();
  late Future<List<Vacunacion>> _futuro = _api.listarVacunaciones(animalId: widget.animal.id);

  void _recargar(String mensaje) {
    if (!mounted) return;
    setState(() {
      _futuro = _api.listarVacunaciones(animalId: widget.animal.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _registrar() async {
    final guardadas = await abrirRegistroVacunacion(context, animal: widget.animal);
    if (guardadas != null) _recargar('Vacunación registrada.');
  }

  Future<void> _editar(Vacunacion v) async {
    final guardadas = await abrirRegistroVacunacion(context, editar: v, animal: widget.animal);
    if (guardadas != null) _recargar('Vacunación corregida.');
  }

  Future<void> _eliminar(Vacunacion v) async {
    if (await eliminarVacunacion(context, v)) _recargar('Vacunación eliminada.');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final activo = widget.animal.activo;

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
                Text('Historial sanitario', style: tema.textTheme.titleMedium),
                if (activo)
                  FilledButton.icon(
                    onPressed: _registrar,
                    icon: const Icon(Icons.vaccines_outlined, size: 18),
                    label: const Text('Registrar vacunación'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Vacunacion>>(
              future: _futuro,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Text(
                    'No se pudo cargar el historial sanitario.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.error),
                  );
                }
                final vacunaciones = snapshot.data!;
                if (vacunaciones.isEmpty) {
                  return Text(
                    'Este animal no tiene vacunaciones registradas.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  );
                }
                return Column(
                  children: [
                    for (final v in vacunaciones)
                      FilaVacunacion(
                        vacunacion: v,
                        onEditar: activo ? () => _editar(v) : null,
                        onEliminar: activo ? () => _eliminar(v) : null,
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
