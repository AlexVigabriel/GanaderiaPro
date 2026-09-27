import 'package:flutter/material.dart';

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
  const AppShell({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    final rutaActual = ModalRoute.of(context)?.settings.name ?? '/';

    return Scaffold(
      appBar: AppBar(
        // HU-15: nombre del rancho actual. El buscador general y las
        // notificaciones quedan como placeholder visual (deshabilitados)
        // hasta que existan sus módulos correspondientes.
        title: const Text('Rancho de prueba (dev)'),
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
            const DrawerHeader(
              child: Text(
                'GanaderíaPro',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            for (final modulo in modulosDisponibles)
              ListTile(
                leading: Icon(modulo.icono),
                title: Text(modulo.titulo),
                selected: rutaActual == modulo.ruta,
                onTap: () {
                  Navigator.of(context).pop();
                  if (rutaActual != modulo.ruta) {
                    Navigator.of(context).pushReplacementNamed(modulo.ruta);
                  }
                },
              ),
          ],
        ),
      ),
      body: body,
    );
  }
}
