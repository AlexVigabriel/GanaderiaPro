import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// HU-45.1: dónde queda guardada la sesión para poder abrir la app sin
// conexión. La app usa el almacenamiento seguro del dispositivo (cifrado);
// las pruebas, memoria.
abstract class BovedaSesion {
  Future<String?> leer();
  Future<void> guardar(String sesion);
  Future<void> borrar();
}

class BovedaSegura implements BovedaSesion {
  static const _clave = 'sesion';
  final _almacen = const FlutterSecureStorage();

  @override
  Future<String?> leer() => _almacen.read(key: _clave);

  @override
  Future<void> guardar(String sesion) => _almacen.write(key: _clave, value: sesion);

  @override
  Future<void> borrar() => _almacen.delete(key: _clave);
}

class BovedaMemoria implements BovedaSesion {
  String? valor;

  @override
  Future<String?> leer() async => valor;

  @override
  Future<void> guardar(String sesion) async => valor = sesion;

  @override
  Future<void> borrar() async => valor = null;
}
