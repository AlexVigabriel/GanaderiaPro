import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'animal.dart';

// HU-45.1: un alta hecha sin conexión, guardada en el dispositivo hasta que
// se pueda enviar al servidor.
class AnimalPendiente {
  const AnimalPendiente({
    required this.idLocal,
    required this.ranchoId,
    required this.datos,
    required this.creado,
  });

  // Identificador creado en el dispositivo; con él el servidor reconoce un
  // reintento y no duplica el registro (HU-47).
  final String idLocal;
  // Solo se sincroniza con una sesión del mismo rancho (RN-16).
  final String ranchoId;
  final DatosAnimal datos;
  final DateTime creado;
}

// Dónde se guardan los pendientes. La app usa SQLite; las pruebas, memoria.
abstract class AlmacenPendientes {
  Future<List<AnimalPendiente>> listar(String ranchoId);
  Future<void> agregar(List<AnimalPendiente> animales);
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
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_tabla (
          id_local TEXT PRIMARY KEY,
          rancho_id TEXT NOT NULL,
          datos TEXT NOT NULL,
          creado TEXT NOT NULL
        )'''),
    ),
  );

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
        ),
    ];
  }

  @override
  Future<void> agregar(List<AnimalPendiente> animales) async {
    final db = await _abierta;
    await db.transaction((t) async {
      for (final a in animales) {
        await t.insert(_tabla, {
          'id_local': a.idLocal,
          'rancho_id': a.ranchoId,
          'datos': jsonEncode(a.datos.toJson()),
          'creado': a.creado.toIso8601String(),
        });
      }
    });
  }

  @override
  Future<void> quitar(String idLocal) async {
    await (await _abierta).delete(_tabla, where: 'id_local = ?', whereArgs: [idLocal]);
  }
}

class AlmacenPendientesMemoria implements AlmacenPendientes {
  final _animales = <AnimalPendiente>[];

  @override
  Future<List<AnimalPendiente>> listar(String ranchoId) async => _animales.where((a) => a.ranchoId == ranchoId).toList();

  @override
  Future<void> agregar(List<AnimalPendiente> animales) async => _animales.addAll(animales);

  @override
  Future<void> quitar(String idLocal) async => _animales.removeWhere((a) => a.idLocal == idLocal);
}
