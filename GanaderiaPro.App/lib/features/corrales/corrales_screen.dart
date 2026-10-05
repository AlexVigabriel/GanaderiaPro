import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/corral.dart';
import '../../core/permisos.dart';
import '../../core/sesion_actual.dart';
import '../../core/widgets/componentes.dart';
import '../shell/app_shell.dart';
import 'corral_dialog.dart';

// HU-24: módulo Corrales. Totales arriba y una tarjeta por corral con sus
// animales activos (sin bajas), la capacidad y el porcentaje de ocupación.
class CorralesScreen extends StatefulWidget {
  const CorralesScreen({super.key});

  @override
  State<CorralesScreen> createState() => _CorralesScreenState();
}

class _CorralesScreenState extends State<CorralesScreen> {
  final _api = ApiClient();
  bool _mostrarInactivos = false;
  late Future<List<Corral>> _corrales = _api.listarCorrales();

  void _recargar() => setState(() {
    _corrales = _api.listarCorrales(incluirInactivos: _mostrarInactivos);
  });

  bool get _puedeEditar => SesionActual.instancia.puedeEditar(Modulos.corrales);

  void _avisar(String mensaje) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));

  Future<void> _crear() async {
    final corral = await abrirFormularioCorral(context);
    if (corral == null || !mounted) return;
    _avisar('Corral «${corral.nombre}» creado.');
    _recargar();
  }

  Future<void> _editar(Corral corral) async {
    final guardado = await abrirFormularioCorral(context, editar: corral);
    if (guardado == null || !mounted) return;
    _avisar('Cambios guardados.');
    _recargar();
  }

  Future<void> _cambiarEstado(Corral corral) async {
    if (corral.activo) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('¿Desactivar «${corral.nombre}»?'),
          content: const Text(
            'Deja de mostrarse en la vista de corrales y no se le pueden asignar animales. '
            'Su historial se conserva y podés volver a activarlo cuando quieras.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Desactivar')),
          ],
        ),
      );
      if (confirmado != true || !mounted) return;
    }

    try {
      await _api.cambiarEstadoCorral(corral.id, activo: !corral.activo);
      if (!mounted) return;
      _avisar(corral.activo ? 'Corral desactivado.' : 'Corral activado.');
      _recargar();
    } on ApiException catch (e) {
      if (mounted) _avisar(e.mensaje);
    } catch (_) {
      if (mounted) _avisar('No se pudo conectar con el servidor.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AppShell(
      seccionActiva: '/corrales',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: FutureBuilder<List<Corral>>(
          future: _corrales,
          builder: (context, snapshot) {
            final corrales = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EncabezadoPantalla(
                  titulo: 'Corrales',
                  subtitulo: 'Organizá la distribución del ganado y controlá la ocupación de cada corral.',
                  soloConsulta: !_puedeEditar,
                  acciones: [
                    if (_puedeEditar)
                      FilledButton.icon(onPressed: _crear, icon: const Icon(Icons.add), label: const Text('Nuevo corral')),
                  ],
                ),
                const SizedBox(height: 24),
                _resumen(corrales == null ? null : ResumenCorrales.de(corrales)),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilterChip(
                    label: const Text('Mostrar inactivos'),
                    selected: _mostrarInactivos,
                    onSelected: (v) {
                      _mostrarInactivos = v;
                      _recargar();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _contenido(snapshot, tema),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _resumen(ResumenCorrales? r) {
    final tarjetas = [
      TarjetaIndicador(etiqueta: 'Corrales', valor: r?.corrales, icono: Icons.fence),
      TarjetaIndicador(etiqueta: 'Animales en corrales', valor: r?.animales, icono: Icons.pets_outlined),
      TarjetaIndicador(etiqueta: 'Ocupación promedio %', valor: r?.ocupacionPromedio, icono: Icons.pie_chart_outline),
    ];
    return LayoutBuilder(
      builder: (context, restricciones) {
        const espacio = 16.0;
        final columnas = restricciones.maxWidth >= 640 ? 3 : 1;
        final ancho = (restricciones.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [for (final t in tarjetas) SizedBox(width: ancho, child: t)],
        );
      },
    );
  }

  Widget _contenido(AsyncSnapshot<List<Corral>> snapshot, ThemeData tema) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    }
    if (snapshot.hasError) {
      return Column(
        children: [
          const SizedBox(height: 24),
          const Text('No se pudieron cargar los corrales.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _recargar, child: const Text('Reintentar')),
        ],
      );
    }

    final corrales = snapshot.data!;
    if (corrales.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            children: [
              Icon(Icons.fence, size: 40, color: tema.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No hay corrales', style: tema.textTheme.titleMedium),
              const SizedBox(height: 4),
              if (_puedeEditar) ...[
                Text(
                  'Creá el primero para organizar tu ganado.',
                  style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(onPressed: _crear, icon: const Icon(Icons.add), label: const Text('Crear el primero')),
              ],
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, restricciones) {
        const espacio = 16.0;
        final columnas = restricciones.maxWidth >= 1000 ? 3 : (restricciones.maxWidth >= 640 ? 2 : 1);
        final ancho = (restricciones.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final c in corrales)
              SizedBox(
                width: ancho,
                child: _TarjetaCorral(
                  corral: c,
                  editable: _puedeEditar,
                  onEditar: () => _editar(c),
                  onCambiarEstado: () => _cambiarEstado(c),
                ),
              ),
          ],
        );
      },
    );
  }
}

// Color de la ocupación: verde hasta 79 %, ámbar de 80 a 99 % y rojo lleno.
Color colorOcupacion(int porcentaje, ColorScheme colores) {
  if (porcentaje >= 100) return colores.error;
  if (porcentaje >= 80) return const Color(0xFFB7791F);
  return colores.primary;
}

class _TarjetaCorral extends StatelessWidget {
  const _TarjetaCorral({
    required this.corral,
    required this.editable,
    required this.onEditar,
    required this.onCambiarEstado,
  });

  final Corral corral;
  // HU-34: sin escritura en Corrales no se muestran editar ni desactivar.
  final bool editable;
  final VoidCallback onEditar;
  final VoidCallback onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = corral;
    final color = c.activo ? colorOcupacion(c.porcentajeOcupacion, tema.colorScheme) : tema.colorScheme.outline;

    return Opacity(
      opacity: c.activo ? 1 : 0.6,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.fence, size: 22, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(c.nombre, style: tema.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (!c.activo) const EtiquetaEstado('Inactivo'),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${c.animalesActivos}', style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5, left: 4),
                    child: Text(
                      '/ ${c.capacidad} animales',
                      style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '${c.porcentajeOcupacion} %',
                      style: tema.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (c.porcentajeOcupacion / 100).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  color: color,
                  backgroundColor: tema.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                c.lugaresLibres <= 0 ? 'Corral lleno' : '${c.lugaresLibres} lugares libres',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              if (editable) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (c.activo) ...[
                    BotonAccion(icono: Icons.edit_outlined, tooltip: 'Editar corral', onPressed: onEditar),
                    const SizedBox(width: 8),
                  ],
                  // RN-08: un corral con animales no se puede desactivar.
                  BotonAccion(
                    icono: c.activo ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    tooltip: !c.activo
                        ? 'Activar corral'
                        : (c.animalesActivos > 0
                              ? (c.animalesActivos == 1
                                    ? 'Tiene 1 animal: reasignalo antes de desactivarlo'
                                    : 'Tiene ${c.animalesActivos} animales: reasignalos antes de desactivarlo')
                              : 'Desactivar corral'),
                    peligro: c.activo,
                    onPressed: c.activo && c.animalesActivos > 0 ? null : onCambiarEstado,
                  ),
                ],
              ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
