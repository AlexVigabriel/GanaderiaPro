import 'package:flutter/material.dart';

import 'core/route_observer.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/registro_screen.dart';
import 'features/ganado/listado_animales_screen.dart';
import 'features/shell/home_screen.dart';

void main() {
  runApp(const GanaderiaProApp());
}

class GanaderiaProApp extends StatelessWidget {
  const GanaderiaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GanaderíaPro',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      navigatorObservers: [routeObserver],
      initialRoute: '/login',
      // Se maneja a mano en vez de con el mapa `routes` de MaterialApp,
      // porque ese mapa exige coincidencia EXACTA del nombre de la ruta —
      // un link externo como "/registro?plan=Superior" (con query string)
      // no matchea "/registro" y termina cayendo por defecto a "/". Acá se
      // separa la ruta de los parámetros antes de comparar.
      onGenerateRoute: (settings) {
        final ruta = Uri.parse(settings.name ?? '/login').path;
        return MaterialPageRoute(
          settings: RouteSettings(name: ruta, arguments: settings.arguments),
          builder: (context) => _pantallaParaRuta(ruta),
        );
      },
    );
  }

  Widget _pantallaParaRuta(String ruta) {
    switch (ruta) {
      case '/registro':
        return const RegistroScreen();
      case '/':
        return const HomeScreen();
      case '/ganado':
        return const ListadoAnimalesScreen();
      case '/login':
      default:
        return const LoginScreen();
    }
  }
}
