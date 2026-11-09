import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Deja la foto lista para incrustarla en el PDF.
/// JPG y PNG pequeños se usan tal cual. El resto se convierte a JPG.
Future<Uint8List?> prepararFotoParaPdf(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) return null;
  if ((_esJpeg(bytes) || _esPng(bytes)) && bytes.length <= 2 * 1024 * 1024) {
    return bytes;
  }
  try {
    final decodificada = img.decodeImage(bytes);
    if (decodificada == null) {
      return _esJpeg(bytes) || _esPng(bytes) ? bytes : null;
    }
    var foto = decodificada;
    const maxLado = 1400;
    if (foto.width > maxLado || foto.height > maxLado) {
      foto = foto.width >= foto.height
          ? img.copyResize(foto, width: maxLado)
          : img.copyResize(foto, height: maxLado);
    }
    return img.encodeJpg(foto, quality: 72);
  } catch (_) {
    return _esJpeg(bytes) || _esPng(bytes) ? bytes : null;
  }
}

bool _esJpeg(Uint8List bytes) =>
    bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

bool _esPng(Uint8List bytes) =>
    bytes.length > 8 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47;
