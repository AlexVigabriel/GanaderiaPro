import 'dart:async';
import 'dart:convert';

import 'boveda_sesion.dart';
import 'permisos.dart';

// Sesión de quien usa la app. HU-45.1: si hay [boveda], además queda
// guardada en el dispositivo para poder abrir la app sin conexión.
class SesionActual {
  SesionActual._();

  static final SesionActual instancia = SesionActual._();

  String? token;
  String? nombreRancho;
  String? nombreUsuario;
  // Propietario, Socio, Veterinario, EncargadoCorrales o EncargadoIngreso.
  String? rol;
  // HU-34: módulo → Ninguno, Lectura o Escritura (lo manda el servidor).
  Map<String, String> permisos = const {};
  // Sin bóveda (por ejemplo, en pruebas) la sesión vive solo en memoria.
  BovedaSesion? boveda;

  bool get estaAutenticado => token != null;
  bool get esPropietario => rol == 'Propietario';

  bool puedeVer(String modulo) => permisos[modulo] == 'Lectura' || permisos[modulo] == 'Escritura';
  bool puedeEditar(String modulo) => permisos[modulo] == 'Escritura';

  // Rancho del token (RN-16): los registros guardados sin conexión quedan
  // asociados a él. Null si el token no se puede leer.
  String? get ranchoId {
    final partes = token?.split('.');
    if (partes == null || partes.length != 3) return null;
    try {
      final datos = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))));
      return (datos as Map<String, dynamic>)['ranchoId'] as String?;
    } catch (_) {
      return null;
    }
  }

  // Sin [permisos] (por ejemplo, en pruebas) el propietario tiene todo.
  void guardar({
    required String token,
    required String nombreRancho,
    required String nombreUsuario,
    String rol = 'Propietario',
    Map<String, String>? permisos,
  }) {
    this.token = token;
    this.nombreRancho = nombreRancho;
    this.nombreUsuario = nombreUsuario;
    this.rol = rol;
    this.permisos = permisos ?? (rol == 'Propietario' ? _todoParaElPropietario : const {});
    unawaited(
      boveda?.guardar(
        jsonEncode({
          'token': token,
          'nombreRancho': nombreRancho,
          'nombreUsuario': nombreUsuario,
          'rol': rol,
          'permisos': this.permisos,
        }),
      ),
    );
  }

  // Al abrir la app: recupera la sesión guardada, si hay una.
  Future<void> restaurar() async {
    final guardada = await boveda?.leer();
    if (guardada == null) return;
    try {
      final datos = jsonDecode(guardada) as Map<String, dynamic>;
      token = datos['token'] as String;
      nombreRancho = datos['nombreRancho'] as String;
      nombreUsuario = datos['nombreUsuario'] as String;
      rol = datos['rol'] as String;
      permisos = (datos['permisos'] as Map<String, dynamic>).map((m, n) => MapEntry(m, n as String));
    } catch (_) {
      // Guardada con otro formato: se descarta y se pide iniciar sesión.
      cerrar();
    }
  }

  void cerrar() {
    token = null;
    nombreRancho = null;
    nombreUsuario = null;
    rol = null;
    permisos = const {};
    unawaited(boveda?.borrar());
  }

  static const _todoParaElPropietario = {
    Modulos.ganado: 'Escritura',
    Modulos.pesaje: 'Escritura',
    Modulos.corrales: 'Escritura',
    Modulos.sanidad: 'Escritura',
    Modulos.colaboradores: 'Escritura',
    Modulos.tablero: 'Lectura',
    Modulos.configuracion: 'Escritura',
  };
}
