import 'permisos.dart';

// Guarda la sesión en memoria mientras la app está abierta. No persiste entre
// reinicios: "Recordarme" es la HU-10.
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

  bool get estaAutenticado => token != null;
  bool get esPropietario => rol == 'Propietario';

  bool puedeVer(String modulo) => permisos[modulo] == 'Lectura' || permisos[modulo] == 'Escritura';
  bool puedeEditar(String modulo) => permisos[modulo] == 'Escritura';

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
  }

  void cerrar() {
    token = null;
    nombreRancho = null;
    nombreUsuario = null;
    rol = null;
    permisos = const {};
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
