import 'dart:typed_data';

class AudioGrabado {
  final Uint8List bytes;
  final String nombre;

  const AudioGrabado({required this.bytes, required this.nombre});
}
