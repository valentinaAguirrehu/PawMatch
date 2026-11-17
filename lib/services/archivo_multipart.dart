import 'package:http_parser/http_parser.dart';
import 'package:paw_match/services/cliente_http.dart' as http;

/// Adjunta bytes con el tipo que corresponde a la extensión del nombre.
///
/// El paquete http usa application/octet-stream si no se indica el tipo, y el
/// Worker rechaza ese tipo aunque la extensión sea válida.
http.MultipartFile archivoMultipart(
  String campo,
  List<int> bytes,
  String nombre,
) {
  final limpio = nombre.trim().isEmpty ? 'archivo.bin' : nombre.trim();
  final punto = limpio.lastIndexOf('.');
  final ext = punto >= 0 ? limpio.substring(punto + 1).toLowerCase() : '';
  final tipo = switch (ext) {
    'png' => MediaType('image', 'png'),
    'jpg' || 'jpeg' || 'jfif' => MediaType('image', 'jpeg'),
    'webp' => MediaType('image', 'webp'),
    'gif' => MediaType('image', 'gif'),
    'bmp' => MediaType('image', 'bmp'),
    'pdf' => MediaType('application', 'pdf'),
    'mp4' => MediaType('video', 'mp4'),
    'mov' => MediaType('video', 'quicktime'),
    'webm' => MediaType('video', 'webm'),
    'avi' => MediaType('video', 'x-msvideo'),
    'mkv' => MediaType('video', 'x-matroska'),
    '3gp' => MediaType('video', '3gpp'),
    _ => MediaType('application', 'octet-stream'),
  };
  return http.MultipartFile.fromBytes(
    campo,
    bytes,
    filename: limpio,
    contentType: tipo,
  );
}
