// Guarda la sesión en memoria mientras la app está abierta. No persiste entre
// reinicios: "Recordarme" (HU-10) es de Sprint 2, no corresponde todavía.
class SesionActual {
  SesionActual._();

  static final SesionActual instancia = SesionActual._();

  String? token;
  String? nombreRancho;
  String? nombreUsuario;
  // Propietario, Socio, Veterinario, EncargadoCorrales o EncargadoIngreso.
  String? rol;

  bool get estaAutenticado => token != null;
  bool get esPropietario => rol == 'Propietario';

  void guardar({required String token, required String nombreRancho, required String nombreUsuario, String rol = 'Propietario'}) {
    this.token = token;
    this.nombreRancho = nombreRancho;
    this.nombreUsuario = nombreUsuario;
    this.rol = rol;
  }

  void cerrar() {
    token = null;
    nombreRancho = null;
    nombreUsuario = null;
    rol = null;
  }
}
