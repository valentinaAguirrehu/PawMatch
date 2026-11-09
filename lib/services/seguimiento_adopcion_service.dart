import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:paw_match/models/seguimiento_adopcion.dart';
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';

/// Seguimiento administrativo de adopciones ya formalizadas.
class SeguimientoAdopcionService {
  SeguimientoAdopcionService._();

  static String get _base => '${ApiService.baseUrl}/seguimiento-adopcion';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-usuario-id': Session.idUsuario ?? '',
  };

  static Future<List<AdopcionActivaSeguimiento>> listarActivas() async {
    final res = await http.get(Uri.parse('$_base/activos'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception(_error(res, 'Error al cargar las adopciones en seguimiento'));
    }
    final lista = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return lista
        .map((j) => AdopcionActivaSeguimiento.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<List<SeguimientoAdopcionItem>> obtenerHistorial(String idSolicitud) async {
    final res = await http.get(Uri.parse('$_base/historial/$idSolicitud'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception(_error(res, 'Error al cargar el historial de seguimientos'));
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final List lista = body is List
        ? body
        : (body is Map && body['seguimientos'] is List ? body['seguimientos'] as List : []);
    return lista
        .map((j) => SeguimientoAdopcionItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> cancelarAdopcion({
    required String idSolicitud,
    required DateTime fechaCancelacion,
    required String motivo,
    required String observacion,
    required bool inhabilitarCuenta,
    Uint8List? foto1,
    String? nombreFoto1,
    Uint8List? foto2,
    String? nombreFoto2,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_base/$idSolicitud/cancelar'));
    req.headers['x-usuario-id'] = Session.idUsuario ?? '';
    req.fields.addAll({
      'fecha_cancelacion': _fecha(fechaCancelacion),
      'motivo': motivo,
      'observacion': observacion.trim(),
      'inhabilitar_cuenta': inhabilitarCuenta ? 'true' : 'false',
    });
    if (foto1 != null) {
      req.files.add(_archivoImagen('foto_1', foto1, nombreFoto1 ?? 'evidencia-1.jpg'));
    }
    if (foto2 != null) {
      req.files.add(_archivoImagen('foto_2', foto2, nombreFoto2 ?? 'evidencia-2.jpg'));
    }
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_error(res, 'Error al cancelar la adopción'));
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  static Future<CancelacionAdopcion> obtenerCancelacion(String idSolicitud) async {
    final res = await http.get(Uri.parse('$_base/$idSolicitud/cancelacion'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception(_error(res, 'Error al cargar el motivo de la cancelación'));
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! Map) throw Exception('Error al cargar el motivo de la cancelación');
    return CancelacionAdopcion.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<List<ItemCalendarioSeguimiento>> obtenerCalendario() async {
    final res = await http.get(Uri.parse('$_base/calendario'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception(_error(res, 'Error al cargar el calendario de seguimientos'));
    }
    final lista = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return lista.map((raw) {
      final json = Map<String, dynamic>.from(raw as Map);
      json['id_seguimiento_apadrinacion'] = json['id_seguimiento_adopcion'];
      json['id_solicitud_apadrinamiento'] = json['id_solicitud_adopcion'];
      json['tiene_tres_incumplimientos'] = false;
      return ItemCalendarioSeguimiento.fromJson(json);
    }).toList();
  }

  static Future<Map<String, dynamic>> crearSeguimiento({
    required String idSolicitud,
    required int calificacion,
    required String observaciones,
    required DateTime fechaSeguimiento,
    required DateTime proximoSeguimiento,
    required int pesoSaludable,
    required int condicionSanitaria,
    required int entornoApto,
    required int comportamiento,
    required int compromisoVeterinario,
    required int disposicionAdoptante,
    required Uint8List fotoEstado,
    required String nombreFotoEstado,
    Uint8List? fotoEntorno,
    String? nombreFotoEntorno,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse(_base));
    req.headers['x-usuario-id'] = Session.idUsuario ?? '';
    req.fields.addAll({
      'id_solicitud_adopcion': idSolicitud,
      'calificacion': '$calificacion',
      'observaciones': observaciones.trim(),
      'fecha_seguimiento': _fecha(fechaSeguimiento),
      'proxima_fecha_seguimiento': _fecha(proximoSeguimiento),
      'peso_saludable': '$pesoSaludable',
      'condicion_sanitaria': '$condicionSanitaria',
      'entorno_apto': '$entornoApto',
      'comportamiento': '$comportamiento',
      'compromiso_veterinario': '$compromisoVeterinario',
      'disposicion_adoptante': '$disposicionAdoptante',
    });
    req.files.add(_archivoImagen('foto_estado', fotoEstado, nombreFotoEstado));
    if (fotoEntorno != null) {
      req.files.add(_archivoImagen('foto_entorno', fotoEntorno, nombreFotoEntorno ?? 'entorno.jpg'));
    }
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_error(res, 'Error al registrar el seguimiento'));
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  static http.MultipartFile _archivoImagen(String campo, Uint8List bytes, String nombre) {
    final limpio = nombre.trim().isEmpty ? 'foto.jpg' : nombre.trim();
    final conExtension = limpio.contains('.') ? limpio : '$limpio.jpg';
    final ext = conExtension.split('.').last.toLowerCase();
    final subtipo = switch (ext) {
      'png' => 'png',
      'gif' => 'gif',
      'webp' => 'webp',
      'bmp' => 'bmp',
      'heic' => 'heic',
      'heif' => 'heif',
      'tif' || 'tiff' => 'tiff',
      'avif' => 'avif',
      'svg' => 'svg+xml',
      'jfif' => 'jpeg',
      _ => 'jpeg',
    };
    return http.MultipartFile.fromBytes(
      campo,
      bytes,
      filename: conExtension,
      contentType: MediaType('image', subtipo),
    );
  }

  static String _fecha(DateTime fecha) {
    return '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
  }

  static String _error(http.Response res, String fallback) {
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map && data['error'] != null) return data['error'].toString();
    } catch (_) {}
    return fallback;
  }
}
