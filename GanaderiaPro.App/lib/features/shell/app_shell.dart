import 'package:flutter/material.dart';

import '../../core/sesion_actual.dart';

class ModuloMenu {
  const ModuloMenu({required this.titulo, required this.icono, required this.ruta});

  final String titulo;
  final IconData icono;
  final String ruta;
}

// HU-14: lista fija de módulos disponibles. Cuando exista la matriz de
// permisos por rol (Release 2, HU-34), esto se filtra según el rol.
const modulosDisponibles = [
  ModuloMenu(titulo: 'Inicio', icono: Icons.home_outlined, ruta: '/'),
  ModuloMenu(titulo: 'Ganado', icono: Icons.pets_outlined, ruta: '/ganado'),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.body, required this.seccionActiva});

  final Widget body;

  // Qué opción del menú se resalta como activa. Se pasa explícitamente
  // desde cada pantalla en vez de inferirse de la ruta de Navigator: las
  // pantallas como "Registrar animal" o "Ficha" se abren sin nombre de
  // ruta propio, así que adivinar por ahí las confundía con "Inicio".
  final String seccionActiva;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // HU-15: nombre del rancho actual. El buscador general y las
        // notificaciones quedan como placeholder visual (deshabilitados)
        // hasta que existan sus módulos correspondientes.
        title: Text(SesionActual.instancia.nombreRancho ?? 'GanaderíaPro'),
        actions: [
          IconButton(
            onPressed: null,
            tooltip: 'Buscar (próximamente)',
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: null,
            tooltip: 'Notificaciones (próximamente)',
            icon: const Icon(Icons.notifications_none),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(child: Icon(Icons.person_outline)),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).appBarTheme.backgroundColor),
              child: Text(
                'GanaderíaPro',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).appBarTheme.foregroundColor,
                ),
              ),
            ),
            for (final modulo in modulosDisponibles)
              ListTile(
                leading: Icon(modulo.icono),
                title: Text(modulo.titulo),
                selected: seccionActiva == modulo.ruta,
                onTap: () {
                  Navigator.of(context).pop();
                  // Siempre navega, aunque ya "estemos ahí" conceptualmente:
                  // desde una sub-pantalla (Registrar/Ficha/Editar) tocar
                  // "Ganado" tiene que llevar al listado de verdad, no
                  // quedarse sin hacer nada. Limpia la pila de navegación
                  // para no dejar pantallas viejas acumuladas atrás.
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(modulo.ruta, (route) => false);
                },
              ),
          ],
        ),
      ),
      body: body,
    );
  }
}
