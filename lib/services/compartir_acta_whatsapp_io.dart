import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

const _canal = MethodChannel('paw_match/whatsapp');

/// En Android abre WhatsApp con el PDF adjunto. En las demás plataformas
/// abre el menú para enviarlo, con WhatsApp entre las opciones.
Future<bool> compartirActaPorWhatsApp({
  required Uint8List bytes,
  required String nombreArchivo,
  required String mensaje,
}) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final abrio = await _canal.invokeMethod<bool>('compartirPdf', {
        'bytes': bytes,
        'nombre': nombreArchivo,
        'mensaje': mensaje,
      });
      if (abrio == true) return true;
    } catch (_) {}
  }

  return Printing.sharePdf(
    bytes: bytes,
    filename: nombreArchivo,
    subject: 'Acta de adopción',
    body: mensaje,
  );
}
