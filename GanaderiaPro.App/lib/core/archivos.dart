import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

// HU-43 y HU-44: elegir y guardar archivos del dispositivo. En la web, guardar
// descarga el archivo. Las pruebas reemplazan [instancia] por una versión falsa.
class ArchivosLocales {
  static ArchivosLocales instancia = ArchivosLocales();

  // Devuelve el nombre y el contenido del Excel elegido, o null si se canceló.
  Future<({String nombre, Uint8List bytes})?> elegirExcel() async {
    // Si se cancela, devuelve una lista vacía.
    final archivos = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (archivos.isEmpty) return null;
    final archivo = archivos.first;
    return (nombre: archivo.name, bytes: await archivo.readAsBytes());
  }

  // Devuelve false si el usuario canceló.
  Future<bool> guardar(String nombre, Uint8List bytes) async {
    final destino = await FilePicker.saveFile(dialogTitle: 'Guardar $nombre', fileName: nombre, bytes: bytes);
    return destino != null;
  }
}
