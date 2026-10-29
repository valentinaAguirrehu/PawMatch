import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:paw_match/services/api_service.dart';

/// Recuperar contraseña:
/// 1) pedir código al correo
/// 2) verificar código de 4 dígitos
/// 3) cambiar contraseña con el código
class RecuperacionService {
  RecuperacionService._();

  static const _cabeceras = {'Content-Type': 'application/json'};

  static Future<void> solicitarCodigo(String correo) async {
    final r = await http.post(
      Uri.parse('${ApiService.baseUrl}/usuarios/olvide-contrasena'),
      headers: _cabeceras,
      body: jsonEncode({'correo': correo.trim()}),
    );
    if (r.statusCode != 200) throw Exception(_error(r));
  }

  static Future<void> verificarCodigo({
    required String correo,
    required String codigo,
  }) async {
    final r = await http.post(
      Uri.parse('${ApiService.baseUrl}/usuarios/verificar-codigo-recuperacion'),
      headers: _cabeceras,
      body: jsonEncode({
        'correo': correo.trim(),
        'codigo': codigo.trim(),
      }),
    );
    if (r.statusCode != 200) throw Exception(_error(r));
  }

  static Future<void> restablecer({
    required String correo,
    required String codigo,
    required String nuevaContrasena,
  }) async {
    final r = await http.post(
      Uri.parse('${ApiService.baseUrl}/usuarios/restablecer-contrasena'),
      headers: _cabeceras,
      body: jsonEncode({
        'correo': correo.trim(),
        'codigo': codigo.trim(),
        'contrasena': nuevaContrasena,
      }),
    );
    if (r.statusCode != 200) throw Exception(_error(r));
  }

  static String _error(http.Response r) {
    try {
      final decoded = jsonDecode(utf8.decode(r.bodyBytes));
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
      return 'Error ${r.statusCode}';
    } catch (_) {
      return 'Error ${r.statusCode}';
    }
  }
}

