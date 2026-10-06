import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'conexion.dart';
import 'pendientes.dart';
import 'sesion_actual.dart';

// Navegador principal de la app: permite volver al login desde cualquier
// lugar (por ejemplo, cuando el servidor rechaza un token ya cerrado).
final navegadorRaiz = GlobalKey<NavigatorState>();

// HU-52: borra la sesión de la app y vuelve al login vaciando la pila de
// pantallas, para que "Atrás" no muestre ninguna pantalla protegida.
void irAlLoginSinSesion({String? mensaje}) {
  SesionActual.instancia.cerrar();
  // Los pendientes quedan guardados, pero sin sesión no se cuentan.
  RegistrosPendientes.instancia.cargar();
  navegadorRaiz.currentState?.pushNamedAndRemoveUntil('/login', (route) => false, arguments: mensaje);
}

// HU-52: si el servidor responde 401 a un pedido con sesión (el token fue
// cerrado en otro dispositivo o venció), se vuelve al login.
class ClienteConSesion extends http.BaseClient {
  ClienteConSesion([http.Client? interno]) : _interno = interno ?? http.Client();

  final http.Client _interno;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final http.StreamedResponse respuesta;
    try {
      respuesta = await _interno.send(request);
    } catch (_) {
      // HU-46: el servidor no respondió.
      EstadoConexion.instancia.informar(enLinea: false);
      rethrow;
    }
    EstadoConexion.instancia.informar(enLinea: true);
    if (respuesta.statusCode == 401 && SesionActual.instancia.estaAutenticado) {
      irAlLoginSinSesion(mensaje: 'Tu sesión se cerró. Iniciá sesión de nuevo.');
    }
    return respuesta;
  }
}
