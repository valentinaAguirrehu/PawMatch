import 'dart:typed_data';

/// Un PDF de cédula, recibo o contrato debe ser pequeño.
/// Las fotos sueltas no usan este límite.
class LimitePdf {
  static const int maximoBytes = 2 * 1024 * 1024;

  static const String mensajePesado =
      'Este PDF está muy pesado. Sube uno más pequeño, de menos de 2 MB.';

  static bool esPdf(String? nombre, [Uint8List? bytes]) {
    final archivo = nombre?.trim().toLowerCase() ?? '';
    if (archivo.endsWith('.pdf')) return true;
    if (bytes != null && bytes.length >= 4) {
      return bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;
    }
    return false;
  }

  static bool estaPesado(String? nombre, int tamano, [Uint8List? bytes]) {
    return esPdf(nombre, bytes) && tamano > maximoBytes;
  }
}
