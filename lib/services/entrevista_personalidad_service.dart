import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:paw_match/models/entrevista_personalidad.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Llamadas de la entrevista. La clave de OpenAI no sale del servidor.
class EntrevistaPersonalidadService {
  static const _vozKey = 'paw_entrevista_voz';

  static String _id() {
    final id = Session.idUsuario;
    if (id == null || id.isEmpty) {
      throw Exception('No hay una sesión activa');
    }
    return id;
  }

  static String _borradorKey(String id) => 'paw_entrevista_$id';

  static Future<List<PreguntaEntrevista>> preguntas() async {
    final id = _id();
    final data = await _json(() => http.get(
          Uri.parse('${ApiService.baseUrl}/usuarios/personalidad/preguntas'),
          headers: {'x-usuario-id': id},
        ));
    final crudas = data['preguntas'];
    if (crudas is! List || crudas.isEmpty) {
      throw Exception('No hay preguntas de personalidad configuradas');
    }
    final lista = <PreguntaEntrevista>[];
    for (final item in crudas) {
      if (item is! Map) {
        throw Exception('No se pudieron leer las preguntas');
      }
      lista.add(PreguntaEntrevista.fromJson(Map<String, dynamic>.from(item)));
    }
    lista.sort((a, b) => a.orden.compareTo(b.orden));
    if (lista.map((p) => p.id).toSet().length != lista.length) {
      throw Exception('Las preguntas del formulario están repetidas');
    }
    return lista;
  }

  static Future<List<RespuestaEntrevista>> borradores() async {
    final id = _id();
    final data = await _json(() => http.get(
          Uri.parse('${ApiService.baseUrl}/usuarios/$id/personalidad/entrevista'),
          headers: {'x-usuario-id': id},
        ));
    final crudas = data['respuestas'];
    if (crudas is! List) return [];
    final lista = <RespuestaEntrevista>[];
    for (final item in crudas) {
      if (item is! Map) continue;
      lista.add(RespuestaEntrevista.fromJson(Map<String, dynamic>.from(item)));
    }
    return lista;
  }

  static Future<InterpretacionEntrevista> interpretar({
    required String clave,
    required String respuesta,
    List<Map<String, String>> contexto = const [],
  }) async {
    final id = _id();
    final data = await _json(
      () => http.post(
        Uri.parse('${ApiService.baseUrl}/usuarios/$id/personalidad/interpretar'),
        headers: {'Content-Type': 'application/json', 'x-usuario-id': id},
        body: jsonEncode({
          'clave': clave,
          'respuesta': respuesta,
          'contexto': contexto,
        }),
      ),
    );
    final interpretacion = InterpretacionEntrevista.fromJson(data);
    if (interpretacion.mensaje.trim().length < 2) {
      throw Exception('El asistente no envió un mensaje para mostrar.');
    }
    if (!interpretacion.necesitaAclaracion && !interpretacion.lista) {
      throw Exception('El asistente no asignó una puntuación válida.');
    }
    if (!interpretacion.necesitaAclaracion &&
        interpretacion.preguntaId != clave) {
      throw Exception('El asistente respondió sobre otra pregunta.');
    }
    return interpretacion;
  }

  static Future<void> eliminar(String clave) async {
    final id = _id();
    final resp = await _peticion(() => http.delete(
          Uri.parse(
            '${ApiService.baseUrl}/usuarios/$id/personalidad/entrevista/$clave',
          ),
          headers: {'x-usuario-id': id},
        ));
    if (resp.statusCode == 200) return;
    throw Exception(_mensaje(_leer(resp), 'No se pudo corregir esa respuesta'));
  }

  static Future<String> transcribir(String ruta) async {
    final id = _id();
    final solicitud = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/usuarios/$id/personalidad/transcribir'),
    );
    solicitud.headers['x-usuario-id'] = id;
    solicitud.files.add(await http.MultipartFile.fromPath('audio', ruta));
    final enviada = await solicitud.send().timeout(const Duration(seconds: 50));
    final resp = await http.Response.fromStream(enviada);
    final data = _leer(resp);
    if (resp.statusCode == 200 && data is Map && data['texto'] != null) {
      final texto = data['texto'].toString().trim();
      if (texto.isNotEmpty) return texto;
    }
    throw Exception(_mensaje(data, 'No se entendió el audio'));
  }

  static Future<BorradorEntrevista?> leerBorradorLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_borradorKey(_id()));
    if (crudo == null || crudo.isEmpty) return null;
    try {
      final data = jsonDecode(crudo);
      if (data is! Map) return null;
      return BorradorEntrevista.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  static Future<void> guardarBorradorLocal(BorradorEntrevista borrador) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_borradorKey(_id()), jsonEncode(borrador.toJson()));
  }

  static Future<void> borrarBorradorLocal() async {
    final id = Session.idUsuario;
    if (id == null || id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_borradorKey(id));
  }

  static Future<bool> vozActiva() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vozKey) ?? true;
  }

  static Future<void> guardarVoz(bool activa) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vozKey, activa);
  }

  static Future<Map<String, dynamic>> _json(
    Future<http.Response> Function() peticion,
  ) async {
    final resp = await _peticion(peticion);
    final data = _leer(resp);
    if (resp.statusCode == 200 && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(_mensaje(data, 'No se pudo completar la entrevista', resp));
  }

  static Future<http.Response> _peticion(
    Future<http.Response> Function() peticion,
  ) async {
    try {
      return await peticion().timeout(const Duration(seconds: 50));
    } catch (error) {
      final texto = error.toString();
      if (error is TimeoutException) {
        throw Exception('La conexión tardó demasiado. Inténtalo de nuevo.');
      }
      if (texto.contains('SocketException') ||
          texto.contains('ClientException') ||
          texto.contains('Failed host lookup') ||
          texto.contains('Connection refused')) {
        throw Exception('No hay conexión con el servidor.');
      }
      rethrow;
    }
  }

  static dynamic _leer(http.Response resp) {
    try {
      return jsonDecode(resp.body);
    } catch (_) {
      return null;
    }
  }

  static String _mensaje(dynamic data, String porDefecto, [http.Response? resp]) {
    if (data is Map && data['error'] != null) return data['error'].toString();
    if (resp != null) return '$porDefecto (HTTP ${resp.statusCode})';
    return porDefecto;
  }
}
