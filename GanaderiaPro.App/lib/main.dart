import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_theme.dart';
import 'core/cerrar_sesion.dart';
import 'core/conexion.dart';
import 'core/permisos.dart';
import 'core/route_observer.dart';
import 'core/sesion_actual.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/registro_screen.dart';
import 'features/auth/aceptar_invitacion_screen.dart';
import 'features/colaboradores/colaboradores_screen.dart';
import 'features/corrales/corrales_screen.dart';
import 'features/ganado/listado_animales_screen.dart';
import 'features/sanidad/sanidad_screen.dart';
import 'features/shell/home_screen.dart';
import 'features/shell/sin_permiso_screen.dart';

void main() {
  // HU-46: vigila si el servidor responde mientras la app está abierta.
  EstadoConexion.instancia.iniciar();
  runApp(const GanaderiaProApp());
}

class GanaderiaProApp extends StatelessWidget {
  const GanaderiaProApp({super.key});

  // Pantallas que solo se ven con sesión iniciada.
  static const _rutasProtegidas = {'/', '/ganado', '/sanidad', '/corrales', '/colaboradores'};

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GanaderíaPro',
      debugShowCheckedModeBanner: false,
      // Textos propios de Flutter (calendario, botones de diálogos) en español.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.claro,
      darkTheme: AppTheme.oscuro,
      // Fijo en claro por decisión del equipo; el interruptor para elegir
      // el modo oscuro y recordar la elección es la HU-72.
      themeMode: ThemeMode.light,
      navigatorKey: navegadorRaiz,
      navigatorObservers: [routeObserver],
      initialRoute: '/login',
      // Por defecto, una ruta inicial como "/login" se trata como enlace
      // profundo y Flutter apila "/" (el Inicio) debajo: el botón "Atrás"
      // llevaba al Inicio sin haber iniciado sesión. Se arranca solo con
      // la pantalla pedida.
      onGenerateInitialRoutes: (rutaInicial) => [_crearRuta(RouteSettings(name: rutaInicial))],
      // Se maneja a mano en vez de con el mapa `routes` de MaterialApp,
      // porque ese mapa exige coincidencia EXACTA del nombre de la ruta —
      // un link externo como "/registro?plan=Superior" (con query string)
      // no matchea "/registro". Acá se separa la ruta de sus parámetros.
      onGenerateRoute: _crearRuta,
    );
  }

  Route<dynamic> _crearRuta(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/login');
    var ruta = uri.path;
    if (_rutasProtegidas.contains(ruta) && !SesionActual.instancia.estaAutenticado) {
      ruta = '/login';
    }
    return MaterialPageRoute(
      settings: RouteSettings(name: ruta, arguments: settings.arguments),
      builder: (context) => _pantallaParaRuta(ruta, uri.queryParameters),
    );
  }

  Widget _pantallaParaRuta(String ruta, Map<String, String> parametros) {
    // HU-34: con sesión pero sin permiso sobre el módulo de la ruta.
    final modulo = moduloDeRuta[ruta];
    if (modulo != null && SesionActual.instancia.estaAutenticado && !SesionActual.instancia.puedeVer(modulo)) {
      return const SinPermisoScreen();
    }

    switch (ruta) {
      case '/registro':
        // HU-05: el plan elegido en el sitio público llega en la ruta
        // ("/registro?plan=Superior"). No se puede leer de Uri.base: con
        // navegación por hash, esa parte queda dentro del fragmento.
        return RegistroScreen(planInicial: parametros['plan']);
      case '/':
        return const HomeScreen();
      case '/ganado':
        return const ListadoAnimalesScreen();
      case '/sanidad':
        return const SanidadScreen();
      case '/corrales':
        return const CorralesScreen();
      case '/colaboradores':
        return const ColaboradoresScreen();
      case '/invitacion':
        return AceptarInvitacionScreen(codigo: parametros['codigo'] ?? '');
      case '/login':
      default:
        return const LoginScreen();
    }
  }
}
