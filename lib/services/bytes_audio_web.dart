import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Uint8List> leerBytesAudio(String ruta) async {
  final respuesta = await web.window.fetch(ruta.toJS).toDart;
  if (!respuesta.ok) {
    throw Exception('No pude leer el audio grabado');
  }
  final buffer = await respuesta.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}
