import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/permisos.dart';
import '../../core/plan.dart';
import '../../core/route_observer.dart';
import '../../core/sesion_actual.dart';
import '../../core/tablero.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/plan_widgets.dart';
import 'app_shell.dart';

// HU-12: tablero con los indicadores generales del rancho. Se recargan cada
// vez que la pantalla vuelve a quedar visible, sin recargar la aplicación.
// Los gráficos (HU-13) quedan para la Release 2.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late Future<ResumenTablero> _resumen = ApiClient().obtenerResumenTablero();

  // HU-58: "Tu plan" solo para el propietario (módulo Configuración).
  final Future<UsoPlan?>? _usoPlan = SesionActual.instancia.puedeVer(Modulos.configuracion)
      ? ApiClient().obtenerUsoPlan().then<UsoPlan?>((u) => u).catchError((_) => null)
      : null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ruta = ModalRoute.of(context);
    if (ruta is PageRoute) routeObserver.subscribe(this, ruta);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Al volver de registrar o dar de baja un animal, los indicadores se
  // actualizan solos.
  @override
  void didPopNext() => _recargar();

  void _recargar() => setState(() => _resumen = ApiClient().obtenerResumenTablero());

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nombre = SesionActual.instancia.nombreUsuario?.split(' ').first;

    return AppShell(
      seccionActiva: '/',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EncabezadoPantalla(
              titulo: nombre == null ? 'Tablero' : 'Hola, $nombre',
              subtitulo: 'Resumen de tu rancho y accesos rápidos.',
            ),
            const SizedBox(height: 28),
            _IndicadoresTablero(resumen: _resumen, alReintentar: _recargar),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/ganado', (r) => false),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: tema.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.pets_outlined, color: tema.colorScheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Animales', style: tema.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Cargá tu ganado y consultá la ficha de cada animal.',
                              style: tema.textTheme.bodyMedium?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward, color: tema.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ),
            if (_usoPlan != null) ...[
              const SizedBox(height: 16),
              FutureBuilder<UsoPlan?>(
                future: _usoPlan,
                builder: (context, snapshot) {
                  final uso = snapshot.data;
                  if (uso == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AvisoLimitePlan(uso: uso, recurso: 'Animales'),
                      AvisoLimitePlan(uso: uso, recurso: 'Colaboradores'),
                      TarjetaPlan(uso: uso),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IndicadoresTablero extends StatelessWidget {
  const _IndicadoresTablero({required this.resumen, required this.alReintentar});

  final Future<ResumenTablero> resumen;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResumenTablero>(
      future: resumen,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final tema = Theme.of(context);
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: tema.colorScheme.error),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('No se pudieron cargar los indicadores.')),
                  TextButton(onPressed: alReintentar, child: const Text('Reintentar')),
                ],
              ),
            ),
          );
        }

        // Mientras carga, las tarjetas muestran «—».
        final r = snapshot.data;
        final tarjetas = [
          TarjetaIndicador(etiqueta: 'Animales activos', valor: r?.animalesActivos, icono: Icons.pets_outlined),
          TarjetaIndicador(etiqueta: 'Machos activos', valor: r?.machosActivos, icono: Icons.male),
          TarjetaIndicador(etiqueta: 'Hembras activas', valor: r?.hembrasActivas, icono: Icons.female),
          TarjetaIndicador(etiqueta: 'Vacunados', valor: r?.vacunados, icono: Icons.verified_outlined),
          TarjetaIndicador(
            etiqueta: 'Vacunaciones pendientes',
            valor: r?.vacunacionesPendientes,
            icono: Icons.event_outlined,
          ),
          TarjetaIndicador(etiqueta: 'Próximas a parir', valor: r?.proximasAParir, icono: Icons.child_friendly),
          TarjetaIndicador(
            etiqueta: 'Fallecidos del año',
            valor: r?.fallecidosDelAnio,
            icono: Icons.heart_broken,
          ),
          TarjetaIndicador(etiqueta: 'Corrales activos', valor: r?.corralesActivos, icono: Icons.fence),
        ];

        return LayoutBuilder(
          builder: (context, restricciones) {
            const espacio = 16.0;
            final columnas = restricciones.maxWidth >= 960
                ? 4
                : restricciones.maxWidth >= 480
                    ? 2
                    : 1;
            final ancho = (restricciones.maxWidth - espacio * (columnas - 1)) / columnas;
            return Wrap(
              spacing: espacio,
              runSpacing: espacio,
              children: [for (final t in tarjetas) SizedBox(width: ancho, child: t)],
            );
          },
        );
      },
    );
  }
}
