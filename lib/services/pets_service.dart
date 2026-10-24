import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/pet.dart';
import 'api_service.dart';
import 'session.dart';

class PetsService {
  static String get _url => '${ApiService.baseUrl}/mascotas';

  /// Notificador con el conteo de mascotas en la base de datos que esperan un hogar (no adoptadas).
  static final ValueNotifier<int> peluditosEsperando = ValueNotifier<int>(0);
  static Timer? _timerMonitoreo;

  static Map<String, String> get _headersAdmin => {
    'Content-Type': 'application/json',
    'x-usuario-id': Session.idUsuario ?? '',
  };

  /// Inicia el monitoreo periódico del conteo de peluditos.
  static void iniciarMonitoreo() {
    refrescarConteo();
    _timerMonitoreo?.cancel();
    _timerMonitoreo = Timer.periodic(const Duration(seconds: 15), (_) {
      refrescarConteo();
    });
  }

  static void detenerMonitoreo() {
    _timerMonitoreo?.cancel();
    _timerMonitoreo = null;
  }

  /// Consulta la base de datos a través de la API y actualiza el contador reactivo.
  static Future<int> refrescarConteo() async {
    try {
      final mascotas = await listar();
      final esperando = mascotas.where((p) => !p.estaAdoptada).length;
      peluditosEsperando.value = esperando;
      return esperando;
    } catch (_) {
      return peluditosEsperando.value;
    }
  }

  /// Lista mascotas. [estado] puede ser 'disponible', 'en_proceso' o 'adoptado'.
  static Future<List<Pet>> listar({String? estado}) async {
    final parametros = <String, String>{
      '_': '${DateTime.now().microsecondsSinceEpoch}',
    };
    if (estado != null) parametros['estado'] = estado;
    final uri = Uri.parse(_url).replace(queryParameters: parametros);
    final resp = await http.get(
      uri,
      headers: const {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    _validar(resp, 200);
    final data = jsonDecode(resp.body) as List<dynamic>;
    final mascotas = data.map((e) => Pet.fromJson(e as Map<String, dynamic>)).toList();
    peluditosEsperando.value = mascotas.where((p) => !p.estaAdoptada).length;
    return mascotas;
  }

  /// Trae una mascota con su personalidad (para el formulario de edición).
  static Future<Pet> obtener(String id) async {
    final resp = await http.get(Uri.parse('$_url/$id'));
    _validar(resp, 200);
    return Pet.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Sube la foto al servidor y devuelve la ruta que hay que guardar en la
  /// mascota (ej: /uploads/mascotas/abc.jpg). Funciona en celular, web y PC.
  static Future<String> subirFoto(Uint8List bytes, String nombreArchivo) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_url/foto'));
    req.headers['x-usuario-id'] = Session.idUsuario ?? '';
    req.files.add(
      http.MultipartFile.fromBytes('foto', bytes, filename: nombreArchivo),
    );
    final resp = await http.Response.fromStream(await req.send());
    _validar(resp, 201);
    return (jsonDecode(resp.body) as Map<String, dynamic>)['ruta'] as String;
  }

  static Future<Pet> crear(Pet pet) async {
    final resp = await http.post(
      Uri.parse(_url),
      headers: _headersAdmin,
      body: jsonEncode(pet.toJson()),
    );
    _validar(resp, 201);
    final creada = Pet.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    unawaited(refrescarConteo());
    return creada;
  }

  static Future<Pet> actualizar(String id, Pet pet) async {
    final resp = await http.put(
      Uri.parse('$_url/$id'),
      headers: _headersAdmin,
      body: jsonEncode(pet.toJson()),
    );
    _validar(resp, 200);
    final editada = Pet.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    unawaited(refrescarConteo());
    return editada;
  }

  static Future<void> eliminar(String id) async {
    final resp = await http.delete(
      Uri.parse('$_url/$id'),
      headers: _headersAdmin,
    );
    _validar(resp, 200);
    unawaited(refrescarConteo());
  }

  static void _validar(http.Response resp, int esperado) {
    if (resp.statusCode == esperado) return;
    String mensaje = 'Error inesperado (${resp.statusCode})';
    try {
      final data = jsonDecode(resp.body);
      if (data is Map && data['error'] != null) mensaje = data['error'];
    } catch (_) {}
    throw Exception(mensaje);
  }
}
