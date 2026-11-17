import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> leerBytesAudio(String ruta) {
  return File(ruta).readAsBytes();
}
