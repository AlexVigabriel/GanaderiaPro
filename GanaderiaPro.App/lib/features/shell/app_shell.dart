import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/cerrar_sesion.dart';
import '../../core/colaborador.dart';
import '../../core/conexion.dart';
import '../../core/formato.dart';
import '../../core/permisos.dart';
import '../../core/sesion_actual.dart';

class ModuloMenu {
  const ModuloMenu({required this.titulo, required this.icono, required this.ruta, required this.modulo});

  final String titulo;
  final IconData icono;
  final String ruta;
  // HU-34: el menú muestra solo los módulos que el rol puede ver.
  final String modulo;
}

// HU-14: módulos del menú; HU-34: se filtran según los permisos del rol.
const modulosDisponibles = [
  ModuloMenu(titulo: 'Tablero', icono: Icons.space_dashboard_outlined, ruta: '/', modulo: Modulos.tablero),
  ModuloMenu(titulo: 'Animales', icono: Icons.pets_outlined, ruta: '/ganado', modulo: Modulos.ganado),
  ModuloMenu(titulo: 'Corrales', icono: Icons.fence, ruta: '/corrales', modulo: Modulos.corrales),
  ModuloMenu(titulo: 'Sanidad', icono: Icons.vaccines_outlined, ruta: '/sanidad', modulo: Modulos.sanidad),
  ModuloMenu(titulo: 'Colaboradores', icono: Icons.group_outlined, ruta: '/colaboradores', modulo: Modulos.colaboradores),
];

// Estructura común de las pantallas internas: menú lateral fijo en
// pantallas anchas (desplegable en celular) y barra superior.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.body, required this.seccionActiva});

  final Widget body;

  // Qué opción del menú se resalta como activa. Se pasa explícitamente
  // desde cada pantalla en vez de inferirse de la ruta de Navigator: las
  // pantallas como "Ficha" se abren sin nombre de ruta propio, así que
  // adivinar por ahí las confundía con el Tablero.
  final String seccionActiva;

  static const double _anchoMenuFijo = 1000;

  @override
  Widget build(BuildContext context) {
    final menuFijo = MediaQuery.sizeOf(context).width >= _anchoMenuFijo;
    final menu = _MenuLateral(seccionActiva: seccionActiva, enCajon: !menuFijo);

    return Scaffold(
      drawer: menuFijo ? null : Drawer(width: 270, child: menu),
      body: Row(
        children: [
          if (menuFijo) SizedBox(width: 250, child: menu),
          Expanded(
            child: Column(
              children: [
                _BarraSuperior(mostrarMenu: !menuFijo),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({required this.mostrarMenu});

  final bool mostrarMenu;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sesion = SesionActual.instancia;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        border: Border(bottom: BorderSide(color: tema.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (mostrarMenu)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Menú',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          // HU-15: nombre del rancho actual.
          Icon(Icons.home_work_outlined, size: 20, color: tema.colorScheme.primary),
          const SizedBox(width: 8),
          // Ocupa todo el ancho libre para que el perfil quede a la derecha;
          // adentro, el nombre se recorta si no entra junto al rol.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    sesion.nombreRancho ?? 'GanaderíaPro',
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                // HU-32: el rol de quien inició sesión, para saber siempre con
                // qué cuenta se está trabajando.
                if (sesion.rol != null) ...[
                  const SizedBox(width: 10),
                  Flexible(child: EtiquetaRol(rol: sesion.rol!)),
                ],
              ],
            ),
          ),
          // HU-46: aparece solo cuando el servidor no responde.
          IndicadorConexion(estado: EstadoConexion.instancia),
          const SizedBox(width: 12),
          // HU-52: menú de perfil con el usuario, el rancho y "Cerrar sesión".
          PopupMenuButton<String>(
            tooltip: 'Perfil',
            position: PopupMenuPosition.under,
            offset: const Offset(0, 8),
            onSelected: (opcion) {
              if (opcion == 'cerrar') cerrarSesion(context);
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sesion.nombreUsuario ?? '', style: tema.textTheme.titleSmall),
                    Text(
                      nombreDeRol(sesion.rol ?? ''),
                      style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      sesion.nombreRancho ?? '',
                      style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'cerrar',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: tema.colorScheme.error),
                    const SizedBox(width: 12),
                    Text('Cerrar sesión', style: TextStyle(color: tema.colorScheme.error)),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: tema.colorScheme.primary,
              foregroundColor: tema.colorScheme.onPrimary,
              child: Text(
                iniciales(sesion.nombreUsuario),
                style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuLateral extends StatelessWidget {
  const _MenuLateral({required this.seccionActiva, required this.enCajon});

  final String seccionActiva;
  final bool enCajon;

  void _ir(BuildContext context, String ruta) {
    if (enCajon) Navigator.of(context).pop();
    // Siempre navega, aunque ya "estemos ahí": desde una sub-pantalla
    // (Ficha, Editar) tocar "Animales" tiene que llevar al listado. Limpia
    // la pila para no dejar pantallas viejas acumuladas atrás.
    Navigator.of(context).pushNamedAndRemoveUntil(ruta, (route) => false);
  }


  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Container(
      color: AppTheme.verdeNoche,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.verdeBrillante,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.grass, size: 20, color: AppTheme.verdeNoche),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'GanaderíaPro',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textos.titleLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            for (final modulo in modulosDisponibles.where((m) => SesionActual.instancia.puedeVer(m.modulo)))
              _OpcionMenu(
                modulo: modulo,
                activa: seccionActiva == modulo.ruta,
                onTap: () => _ir(context, modulo.ruta),
              ),
            const Spacer(),
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton.icon(
                onPressed: () => cerrarSesion(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF8A80),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionMenu extends StatelessWidget {
  const _OpcionMenu({required this.modulo, required this.activa, required this.onTap});

  final ModuloMenu modulo;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activa ? Colors.white : Colors.white70;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: activa ? AppTheme.verdeBrillante.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(modulo.icono, size: 20, color: activa ? AppTheme.verdeBrillante : color),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    modulo.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// HU-52: cierra la sesión en el servidor (el token deja de servir) y vuelve
// al login sin dejar pantallas protegidas detrás del botón "Atrás".
Future<void> cerrarSesion(BuildContext context) async {
  final cajon = Scaffold.maybeOf(context);
  if (cajon?.isDrawerOpen ?? false) cajon!.closeDrawer();
  try {
    await ApiClient().cerrarSesion();
  } catch (_) {
    // Sin conexión: la sesión se cierra igual en este dispositivo.
  }
  irAlLoginSinSesion();
}

// Rol del usuario en la barra superior.
class EtiquetaRol extends StatelessWidget {
  const EtiquetaRol({super.key, required this.rol});

  final String rol;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final color = rol == 'Propietario' ? colores.primary : colores.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        nombreDeRol(rol),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// HU-46: aviso "Sin conexión" con la cantidad de registros que esperan
// sincronizarse. Desaparece solo cuando el servidor vuelve a responder.
class IndicadorConexion extends StatelessWidget {
  const IndicadorConexion({super.key, required this.estado});

  final EstadoConexion estado;

  static const _ambar = Color(0xFFE8A317);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        if (estado.enLinea) return const SizedBox.shrink();
        final n = estado.pendientes;
        final pendientes = n == 1 ? '1 pendiente' : '$n pendientes';
        final textos = Theme.of(context).textTheme;
        // En celular solo entra el ícono con la cantidad.
        final compacto = MediaQuery.sizeOf(context).width < 600;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Tooltip(
            message: 'Sin conexión · $pendientes. Lo que registres se guarda en este dispositivo y se envía al volver la conexión.',
            child: Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _ambar.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _ambar.withValues(alpha: 0.6)),
                boxShadow: [BoxShadow(color: _ambar.withValues(alpha: 0.25), blurRadius: 12)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 18, color: _ambar),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: compacto
                            ? [TextSpan(text: '$n', style: const TextStyle(fontWeight: FontWeight.w700))]
                            : [
                                const TextSpan(text: 'Sin conexión', style: TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: ' · $pendientes'),
                              ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textos.labelMedium?.copyWith(color: const Color(0xFF8A5A00)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
