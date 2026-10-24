import 'dart:typed_data';

/// En esta plataforma no se puede adjuntar el PDF a WhatsApp.
Future<bool> compartirActaPorWhatsApp({
  required Uint8List bytes,
  required String nombreArchivo,
  required String mensaje,
}) async {
  return false;
}
