import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'animal.dart';

// HU-47: un pendiente espera enviarse; uno en conflicto fue rechazado por el
// servidor (por ejemplo, identificación repetida) y espera que el usuario lo
// corrija o lo descarte. Nunca se borra solo.
enum EstadoPendiente { pendiente, conflicto }

// HU-45.1: un alta hecha sin conexión, guardada en el dispositivo hasta que
// se pueda enviar al servidor.
class AnimalPendiente {
  const AnimalPendiente({
    required this.idLocal,
    required this.ranchoId,
    required this.datos,
    required this.creado,
    this.estado = EstadoPendiente.pendiente,
    this.motivo,
  });

  // Identificador creado en el dispositivo; con él el servidor reconoce un
  // reintento y no duplica el registro (HU-47).
  final String idLocal;
  // Solo se sincroniza con una sesión del mismo rancho (RN-16).
  final String ranchoId;
  final DatosAnimal datos;
  final DateTime creado;
  final EstadoPendiente estado;
  // Por qué lo rechazó el servidor (solo en conflicto).
  final String? motivo;

  bool get enConflicto => estado == EstadoPendiente.conflicto;

  AnimalPendiente conflicto(String motivo) => AnimalPendiente(
    idLocal: idLocal,
    ranchoId: ranchoId,
    datos: datos,
    creado: creado,
    estado: EstadoPendiente.conflicto,
    motivo: motivo,
  );

  // Corregido por el usuario: vuelve a la cola con los datos nuevos.
  AnimalPendiente corregido(DatosAnimal nuevos) =>
      AnimalPendiente(idLocal: idLocal, ranchoId: ranchoId, datos: nuevos, creado: creado);
}

// Dónde se guardan los pendientes. La app usa SQLite; las pruebas, memoria.
abstract class AlmacenPendientes {
  Future<List<AnimalPendiente>> listar(String ranchoId);
  Future<void> agregar(List<AnimalPendiente> animales);
  Future<void> actualizar(AnimalPendiente animal);
  Future<void> quitar(String idLocal);
}

class AlmacenPendientesSqlite implements AlmacenPendientes {
  static const _tabla = 'animales_pendientes';

  Future<Database>? _base;

  // En el navegador, SQLite corre con el archivo web/sqlite3.wasm y guarda
  // los datos en el almacenamiento del navegador: sobreviven al cerrarlo.
  Future<Database> get _abierta => _base ??= (kIsWeb ? databaseFactoryFfiWebNoWebWorker : databaseFactory).openDatabase(
    'ganaderiapro.db',
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_tabla (
            id_local TEXT PRIMARY KEY,
            rancho_id TEXT NOT NULL,
            datos TEXT NOT NULL,
            creado TEXT NOT NULL
          )''');
        await _agregarEstado(db);
      },
      // Versión 1 (HU-45.1) → 2 (HU-47): se agregan el estado y el motivo
      // sin tocar los pendientes que ya había.
      onUpgrade: (db, anterior, _) async {
        if (anterior < 2) await _agregarEstado(db);
      },
    ),
  );

  static Future<void> _agregarEstado(Database db) async {
    await db.execute("ALTER TABLE $_tabla ADD COLUMN estado TEXT NOT NULL DEFAULT 'pendiente'");
    await db.execute('ALTER TABLE $_tabla ADD COLUMN motivo TEXT');
  }

  @override
  Future<List<AnimalPendiente>> listar(String ranchoId) async {
    final filas = await (await _abierta).query(
      _tabla,
      where: 'rancho_id = ?',
      whereArgs: [ranchoId],
      orderBy: 'creado',
    );
    return [
      for (final f in filas)
        AnimalPendiente(
          idLocal: f['id_local'] as String,
          ranchoId: f['rancho_id'] as String,
          datos: DatosAnimal.fromJson(jsonDecode(f['datos'] as String) as Map<String, dynamic>),
          creado: DateTime.parse(f['creado'] as String),
          estado: EstadoPendiente.values.byName(f['estado'] as String),
          motivo: f['motivo'] as String?,
        ),
    ];
  }

  Map<String, Object?> _fila(AnimalPendiente a) => {
    'id_local': a.idLocal,
    'rancho_id': a.ranchoId,
    'datos': jsonEncode(a.datos.toJson()),
    'creado': a.creado.toIso8601String(),
    'estado': a.estado.name,
    'motivo': a.motivo,
  };

  @override
  Future<void> agregar(List<AnimalPendiente> animales) async {
    final db = await _abierta;
    await db.transaction((t) async {
      for (final a in animales) {
        await t.insert(_tabla, _fila(a));
      }
    });
  }

  @override
  Future<void> actualizar(AnimalPendiente animal) async {
    await (await _abierta).update(_tabla, _fila(animal), where: 'id_local = ?', whereArgs: [animal.idLocal]);
  }

  @override
  Future<void> quitar(String idLocal) async {
    await (await _abierta).delete(_tabla, where: 'id_local = ?', whereArgs: [idLocal]);
  }
}

class AlmacenPendientesMemoria implements AlmacenPendientes {
  final _animales = <AnimalPendiente>[];

  @override
  Future<List<AnimalPendiente>> listar(String ranchoId) async =>
      _animales.where((a) => a.ranchoId == ranchoId).toList();

  @override
  Future<void> agregar(List<AnimalPendiente> animales) async => _animales.addAll(animales);

  @override
  Future<void> actualizar(AnimalPendiente animal) async {
    final i = _animales.indexWhere((a) => a.idLocal == animal.idLocal);
    if (i >= 0) _animales[i] = animal;
  }

  @override
  Future<void> quitar(String idLocal) async => _animales.removeWhere((a) => a.idLocal == idLocal);
}
