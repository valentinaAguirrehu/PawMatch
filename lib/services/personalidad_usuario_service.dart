import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';

/// Lectura, alta y edición del cuestionario en `personalidadusuario`.
class PersonalidadUsuarioService {
  static Future<bool> existe(String idUsuario) async {
    final resp = await http.get(
      Uri.parse('${ApiService.baseUrl}/usuarios/$idUsuario/personalidad'),
      headers: {'x-usuario-id': Session.idUsuario ?? idUsuario},
    );
    final data = _leer(resp);
    if (resp.statusCode == 200 && data is Map && data['existe'] is bool) {
      return data['existe'] as bool;
    }
    throw Exception(_mensaje(data, 'No se pudo consultar tu personalidad'));
  }

  /// Inserta las respuestas del usuario en sesión. Si ya existían, no falla:
  /// el flujo sigue hacia el inicio.
  static Future<void> guardar(Map<String, int> valores) async {
    final id = Session.idUsuario;
    if (id == null || id.isEmpty) {
      throw Exception('No hay una sesión activa');
    }
    final resp = await http.post(
      Uri.parse('${ApiService.baseUrl}/usuarios/$id/personalidad'),
      headers: {'Content-Type': 'application/json', 'x-usuario-id': id},
      body: jsonEncode(valores),
    );
    if (resp.statusCode == 201 || resp.statusCode == 409) return;
    throw Exception(
      _mensaje(_leer(resp), 'No se pudo guardar tu personalidad'),
    );
  }

  /// Respuestas guardadas del usuario en sesión. `null` si todavía no hay fila.
  static Future<Map<String, int>?> obtener() async {
    final id = _idSesion();
    final resp = await http.get(
      Uri.parse('${ApiService.baseUrl}/usuarios/$id/personalidad').replace(
        queryParameters: {'_': '${DateTime.now().microsecondsSinceEpoch}'},
      ),
      headers: {
        'x-usuario-id': id,
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    final data = _leer(resp);
    if (resp.statusCode != 200 || data is! Map) {
      throw Exception(_mensaje(data, 'No se pudo consultar tu personalidad'));
    }
    if (data['existe'] != true) return null;

    final valores = <String, int>{};
    for (final r in rasgosMascota) {
      final n = _entero(data[r.clave]);
      if (n == null || n < 1 || n > 5) {
        throw Exception('No se pudo leer tu personalidad');
      }
      valores[r.clave] = n;
    }
    return valores;
  }

  /// Actualiza la fila existente y `fecha_actualizacion` en el servidor.
  static Future<void> actualizar(Map<String, int> valores) async {
    final id = _idSesion();
    final resp = await http.put(
      Uri.parse('${ApiService.baseUrl}/usuarios/$id/personalidad'),
      headers: {'Content-Type': 'application/json', 'x-usuario-id': id},
      body: jsonEncode(valores),
    );
    if (resp.statusCode == 200) return;
    throw Exception(
      _mensaje(_leer(resp), 'No se pudo actualizar tu personalidad'),
    );
  }

  static String _idSesion() {
    final id = Session.idUsuario;
    if (id == null || id.isEmpty) {
      throw Exception('No hay una sesión activa');
    }
    return id;
  }

  static int? _entero(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static dynamic _leer(http.Response resp) {
    try {
      return jsonDecode(resp.body);
    } catch (_) {
      return null;
    }
  }

  static String _mensaje(dynamic data, String porDefecto) {
    if (data is Map && data['error'] != null) return data['error'].toString();
    return porDefecto;
  }
}
