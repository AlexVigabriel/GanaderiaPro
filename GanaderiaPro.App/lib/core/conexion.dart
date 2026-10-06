import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Dirección del backend (local en desarrollo).
const urlServidor = 'http://localhost:5199';

// HU-46: sabe si el servidor responde y cuántos registros esperan
// sincronizarse. No alcanza con saber si hay Wi-Fi: puede haber red y que el
// servidor no conteste, por eso se le pregunta directamente.
class EstadoConexion extends ChangeNotifier {
  EstadoConexion();

  static final EstadoConexion instancia = EstadoConexion();

  // Pregunta cada 2 s y espera 2 s la respuesta: si la conexión se corta,
  // el aviso aparece en 4 s como máximo (el criterio pide 5).
  static const intervalo = Duration(seconds: 2);
  static const espera = Duration(seconds: 2);

  bool _enLinea = true;
  int _pendientes = 0;
  Timer? _temporizador;
  bool _verificando = false;

  bool get enLinea => _enLinea;
  int get pendientes => _pendientes;

  set pendientes(int cantidad) {
    if (cantidad == _pendientes) return;
    _pendientes = cantidad;
    notifyListeners();
  }

  // También lo usa el cliente HTTP: si un pedido falla por red, el aviso
  // aparece en el momento, sin esperar la próxima pregunta.
  void informar({required bool enLinea}) {
    if (enLinea == _enLinea) return;
    _enLinea = enLinea;
    notifyListeners();
  }

  void iniciar() {
    _temporizador ??= Timer.periodic(intervalo, (_) => verificar());
    verificar();
  }

  void detener() {
    _temporizador?.cancel();
    _temporizador = null;
  }

  Future<void> verificar() async {
    if (_verificando) return;
    _verificando = true;
    try {
      final respuesta = await http.get(Uri.parse('$urlServidor/api/salud')).timeout(espera);
      informar(enLinea: respuesta.statusCode < 500);
    } catch (_) {
      informar(enLinea: false);
    } finally {
      _verificando = false;
    }
  }
}
