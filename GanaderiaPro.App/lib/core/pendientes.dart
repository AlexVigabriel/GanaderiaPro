import 'dart:math';

import 'package:flutter/foundation.dart';

import 'almacen_local.dart';
import 'animal.dart';
import 'conexion.dart';
import 'sesion_actual.dart';

// HU-45.1: altas hechas sin conexión que esperan enviarse al servidor.
class RegistrosPendientes extends ChangeNotifier {
  RegistrosPendientes._();

  static final RegistrosPendientes instancia = RegistrosPendientes._();

  // Las pruebas lo cambian por uno en memoria.
  AlmacenPendientes almacen = AlmacenPendientesSqlite();

  List<AnimalPendiente> _animales = const [];

  List<AnimalPendiente> get animales => _animales;

  // Lee los pendientes del rancho de la sesión actual.
  Future<void> cargar() async {
    final ranchoId = SesionActual.instancia.ranchoId;
    _animales = ranchoId == null ? const [] : await almacen.listar(ranchoId);
    EstadoConexion.instancia.pendientes = _animales.length;
    notifyListeners();
  }

  // RN-01 sin conexión: no se puede repetir una identificación que ya
  // espera sincronizarse en este dispositivo.
  bool contieneArete(String arete) => _animales.any((a) => a.datos.arete == arete);

  Future<void> guardar(List<DatosAnimal> datos) async {
    final ranchoId = SesionActual.instancia.ranchoId;
    if (ranchoId == null) throw StateError('No hay una sesión válida para guardar sin conexión.');
    final ahora = DateTime.now();
    await almacen.agregar([
      for (final d in datos) AnimalPendiente(idLocal: nuevoIdLocal(), ranchoId: ranchoId, datos: d, creado: ahora),
    ]);
    await cargar();
  }

  // Identificador único al azar con formato GUID (v4), como los del servidor.
  static String nuevoIdLocal() {
    final azar = Random.secure();
    final b = List<int>.generate(16, (_) => azar.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
