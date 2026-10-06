import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:paw_match/services/api_service.dart';

/// Recuperar contraseña: 1) pedir código al correo, 2) cambiarla con el código.
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

  static Future<void> restablecer({
    required String correo,
    required String codigo,
    required String nuevaContrasena,
  }) async {
    final r = await http.post(
      Uri.parse('${ApiService.baseUrl}/usuarios/restablecer-contrasena'),
      headers: _cabeceras,
      body: jsonEncode({'correo': correo.trim(), 'codigo': codigo.trim(), 'contrasena': nuevaContrasena}),
    );
    if (r.statusCode != 200) throw Exception(_error(r));
  }

  static String _error(http.Response r) {
    try {
      return (jsonDecode(r.body)['error'] ?? 'Error ${r.statusCode}').toString();
    } catch (_) {
      return 'Error ${r.statusCode}';
    }
  }
}
