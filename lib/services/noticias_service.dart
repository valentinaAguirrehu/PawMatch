import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/noticia.dart';
import 'api_service.dart';
import 'session.dart';

class NoticiasService {
  static String get _url => '${ApiService.baseUrl}/noticias';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (Session.idUsuario != null && Session.idUsuario!.isNotEmpty)
      'x-usuario-id': Session.idUsuario!,
  };

  static Map<String, String> get _headersAdmin => {
    'Content-Type': 'application/json',
    'x-usuario-id': Session.idUsuario ?? '',
  };

  /// Lista todas las noticias registradas en la base de datos
  static Future<List<Noticia>> listar() async {
    final resp = await http.get(Uri.parse(_url), headers: _headers);
    _validar(resp, 200);
    final data = jsonDecode(resp.body) as List<dynamic>;
    return data.map((e) => Noticia.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Sube una foto para la noticia y devuelve su ruta relativa
  static Future<String> subirFoto(Uint8List bytes, String nombreArchivo) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_url/foto'));
    req.headers['x-usuario-id'] = Session.idUsuario ?? '';
    req.files.add(
      http.MultipartFile.fromBytes('foto', bytes, filename: nombreArchivo),
    );
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    _validar(resp, 201);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['ruta'] as String;
  }

  /// Crea una nueva noticia (solo admin)
  static Future<Noticia> crear(Noticia noticia) async {
    final resp = await http.post(
      Uri.parse(_url),
      headers: _headersAdmin,
      body: jsonEncode(noticia.toJson()),
    );
    _validar(resp, 201);
    return Noticia.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Actualiza una noticia existente (solo admin)
  static Future<Noticia> actualizar(String id, Noticia noticia) async {
    final resp = await http.put(
      Uri.parse('$_url/$id'),
      headers: _headersAdmin,
      body: jsonEncode(noticia.toJson()),
    );
    _validar(resp, 200);
    return Noticia.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Elimina una noticia (solo admin)
  static Future<void> eliminar(String id) async {
    final resp = await http.delete(
      Uri.parse('$_url/$id'),
      headers: _headersAdmin,
    );
    _validar(resp, 200);
  }

  /// Alterna el "Me gusta" de una noticia para el usuario actual
  static Future<Map<String, dynamic>> toggleLike(String id) async {
    final resp = await http.post(
      Uri.parse('$_url/$id/like'),
      headers: _headers,
    );
    _validar(resp, 200);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static void _validar(http.Response resp, int esperado) {
    if (resp.statusCode == esperado) return;
    String mensaje = 'Error inesperado (${resp.statusCode})';
    try {
      final data = jsonDecode(resp.body);
      if (data is Map && data['error'] != null) {
        mensaje = data['error'].toString();
      }
    } catch (_) {}
    throw Exception(mensaje);
  }
}
