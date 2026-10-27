import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// En el celular, el navegador abre el menú de compartir con el PDF listo
/// para enviarlo por WhatsApp. En el computador el navegador no permite
/// adjuntar archivos a WhatsApp.
Future<bool> compartirActaPorWhatsApp({
  required Uint8List bytes,
  required String nombreArchivo,
  required String mensaje,
}) async {
  try {
    final archivo = web.File(
      [bytes.toJS].toJS,
      nombreArchivo,
      web.FilePropertyBag(type: 'application/pdf'),
    );
    final datos = web.ShareData(
      files: [archivo].toJS,
      title: 'Acta de adopción',
      text: mensaje,
    );
    final navigator = web.window.navigator;
    if (!navigator.canShare(datos)) return false;
    await navigator.share(datos).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
