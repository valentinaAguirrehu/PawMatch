import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// En el navegador la foto se reduce con el propio Chrome.
/// Decodificarla en Dart dejaba el botón de descarga cargando sin terminar.
Future<Uint8List?> prepararFotoParaPdf(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    final elemento = web.HTMLImageElement()..src = url;
    await elemento.decode().toDart.timeout(const Duration(seconds: 12));
    final ancho = elemento.naturalWidth;
    final alto = elemento.naturalHeight;
    web.URL.revokeObjectURL(url);
    if (ancho <= 0 || alto <= 0) {
      return _directa(bytes);
    }

    const maxLado = 1400;
    var w = ancho;
    var h = alto;
    if (w > maxLado || h > maxLado) {
      if (w >= h) {
        h = (h * maxLado / w).round().clamp(1, maxLado);
        w = maxLado;
      } else {
        w = (w * maxLado / h).round().clamp(1, maxLado);
        h = maxLado;
      }
    }

    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) return _directa(bytes);
    ctx.drawImage(elemento, 0, 0, w, h);
    final dataUrl = canvas.toDataURL('image/jpeg', 0.72.toJS);
    final coma = dataUrl.indexOf(',');
    if (coma < 0) return _directa(bytes);
    return base64Decode(dataUrl.substring(coma + 1));
  } catch (_) {
    return _directa(bytes);
  }
}

Uint8List? _directa(Uint8List bytes) {
  final jpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  final png = bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
  return jpeg || png ? bytes : null;
}
