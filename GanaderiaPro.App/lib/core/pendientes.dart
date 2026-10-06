import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'almacen_local.dart';
import 'animal.dart';
import 'api_client.dart';
import 'conexion.dart';
import 'sesion_actual.dart';

// HU-45.1: altas hechas sin conexión que esperan enviarse al servidor.
// HU-47: cola de salida (patrón Outbox): se envían solas cuando hay conexión.
class RegistrosPendientes extends ChangeNotifier {
  RegistrosPendientes._();

  static final RegistrosPendientes instancia = RegistrosPendientes._();

  // Con pendientes y conexión, se intenta cada 10 s: el envío ocurre en
  // 30 s como máximo después de volver la conexión (en general, al instante).
  static const intervalo = Duration(seconds: 10);

  // Las pruebas lo cambian por uno en memoria.
  AlmacenPendientes almacen = AlmacenPendientesSqlite();
  // Cómo mostrar "Conexión restaurada: N registros sincronizados".
  void Function(String mensaje)? avisar;

  List<AnimalPendiente> _animales = const [];
  Timer? _temporizador;
  bool _sincronizando = false;
  bool _enLineaAntes = true;

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
  bool contieneArete(String arete, {String? excepto}) =>
      _animales.any((a) => a.datos.arete == arete && a.idLocal != excepto);

  Future<void> guardar(List<DatosAnimal> datos) async {
    final ranchoId = SesionActual.instancia.ranchoId;
    if (ranchoId == null) throw StateError('No hay una sesión válida para guardar sin conexión.');
    final ahora = DateTime.now();
    await almacen.agregar([
      for (final d in datos) AnimalPendiente(idLocal: nuevoIdLocal(), ranchoId: ranchoId, datos: d, creado: ahora),
    ]);
    await cargar();
  }

  // HU-47: el usuario corrige un registro en conflicto y vuelve a la cola.
  Future<void> corregir(AnimalPendiente animal, DatosAnimal datos) async {
    await almacen.actualizar(animal.corregido(datos));
    await cargar();
    unawaited(sincronizar());
  }

  Future<void> descartar(AnimalPendiente animal) async {
    await almacen.quitar(animal.idLocal);
    await cargar();
  }

  void iniciarSincronizacion() {
    _temporizador ??= Timer.periodic(intervalo, (_) => sincronizar());
    _enLineaAntes = EstadoConexion.instancia.enLinea;
    EstadoConexion.instancia
      ..removeListener(_cambioConexion)
      ..addListener(_cambioConexion);
    unawaited(sincronizar());
  }

  void detenerSincronizacion() {
    _temporizador?.cancel();
    _temporizador = null;
    EstadoConexion.instancia.removeListener(_cambioConexion);
  }

  // Al volver la conexión se envía en el momento, sin esperar al temporizador.
  void _cambioConexion() {
    final volvio = !_enLineaAntes && EstadoConexion.instancia.enLinea;
    _enLineaAntes = EstadoConexion.instancia.enLinea;
    if (volvio) unawaited(sincronizar());
  }

  // Envía los pendientes. Cada uno lleva su id local: si el envío se corta y
  // se reintenta, el servidor reconoce los que ya llegaron y no los duplica.
  // Los rechazados quedan en conflicto con el motivo; no se borran.
  // Devuelve cuántos quedaron registrados en el servidor.
  Future<int> sincronizar() async {
    final conexion = EstadoConexion.instancia;
    final aEnviar = _animales.where((a) => !a.enConflicto).toList();
    if (_sincronizando || aEnviar.isEmpty || !conexion.enLinea || !SesionActual.instancia.estaAutenticado) return 0;

    _sincronizando = true;
    conexion.sincronizando = true;
    try {
      final resultado = await ApiClient().registrarLote(
        aEnviar.map((a) => a.datos).toList(),
        idsCliente: aEnviar.map((a) => a.idLocal).toList(),
      );
      final rechazos = {for (final r in resultado.rechazados) r.fila - 1: r.motivo};
      for (var i = 0; i < aEnviar.length; i++) {
        final motivo = rechazos[i];
        if (motivo == null) {
          await almacen.quitar(aEnviar[i].idLocal);
        } else {
          await almacen.actualizar(aEnviar[i].conflicto(motivo));
        }
      }
      await cargar();

      final enviados = aEnviar.length - rechazos.length;
      final partes = [
        if (enviados > 0) enviados == 1 ? '1 registro sincronizado' : '$enviados registros sincronizados',
        if (rechazos.isNotEmpty) rechazos.length == 1 ? '1 con conflicto' : '${rechazos.length} con conflicto',
      ];
      avisar?.call('Conexión restaurada: ${partes.join(' · ')}');
      return enviados;
    } catch (_) {
      // Sin respuesta o error del servidor: quedan en la cola y se reintenta.
      return 0;
    } finally {
      _sincronizando = false;
      conexion.sincronizando = false;
    }
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
