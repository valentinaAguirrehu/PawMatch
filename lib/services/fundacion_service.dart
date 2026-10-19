import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';

/// Lectura y edición de la tabla `informacionfundacion`.
class FundacionService {
  static String get _url => '${ApiService.baseUrl}/fundacion';

  /// Trae la información y la deja en [FundacionInfo]. Si falla, se quedan
  /// los valores que ya había (no rompe la página de bienvenida).
  static Future<bool> cargar() async {
    try {
      final resp = await http.get(
        Uri.parse(_url).replace(
          queryParameters: {'_': '${DateTime.now().microsecondsSinceEpoch}'},
        ),
      );
      if (resp.statusCode != 200) return false;
      final data = jsonDecode(resp.body);
      if (data is! Map<String, dynamic>) return false;
      FundacionInfo.aplicar(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Guarda todos los campos (los vacíos quedan como NULL en la base de datos).
  static Future<void> guardar(Map<String, dynamic> datos) async {
    final resp = await http.put(
      Uri.parse(_url),
      headers: {
        'Content-Type': 'application/json',
        'x-usuario-id': Session.idUsuario ?? '',
      },
      body: jsonEncode(datos),
    );
    final data = _leer(resp);
    if (resp.statusCode == 200 && data is Map<String, dynamic>) {
      FundacionInfo.aplicar(data);
      return;
    }
    throw Exception(_mensaje(data, resp, 'No se pudo guardar la información'));
  }

  /// Sube una imagen y devuelve la ruta (/uploads/fundacion/...).
  static Future<String> subirImagen(Uint8List bytes, String nombreArchivo) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_url/imagen'));
    req.headers['x-usuario-id'] = Session.idUsuario ?? '';
    req.files.add(
      http.MultipartFile.fromBytes('foto', bytes, filename: nombreArchivo),
    );
    final resp = await http.Response.fromStream(await req.send());
    final data = _leer(resp);
    if (resp.statusCode == 201 && data is Map && data['ruta'] is String) {
      return data['ruta'] as String;
    }
    throw Exception(_mensaje(data, resp, 'No se pudo subir la imagen'));
  }

  static dynamic _leer(http.Response resp) {
    try {
      return jsonDecode(resp.body);
    } catch (_) {
      return null;
    }
  }

  static String _mensaje(dynamic data, http.Response resp, String porDefecto) {
    if (data is Map && data['error'] != null) return data['error'].toString();
    if (resp.statusCode == 404) {
      return '$porDefecto (HTTP 404). Reinicia el backend con: node server.js';
    }
    return '$porDefecto (HTTP ${resp.statusCode})';
  }
}
