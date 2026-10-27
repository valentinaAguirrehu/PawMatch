import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';

/// Servicio para la gestión de Seguimiento de Apadrinamiento en PawMatch.
class SeguimientoApadrinamientoService {
  SeguimientoApadrinamientoService._();

  static String get _urlPrincipal => '${ApiService.baseUrl}/seguimiento-apadrinamiento';
  static String get _urlAlterna => '${ApiService.baseUrl}/solicitudes-apadrinamiento/seguimiento';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-usuario-id': Session.idUsuario ?? '',
  };

  /// Ejecuta una petición HTTP intentando la ruta principal y haciendo fallback si es necesario.
  static Future<http.Response> _peticionConFallback(
    String metodo,
    String ruta, {
    Map<String, dynamic>? body,
  }) async {
    final uri1 = Uri.parse('$_urlPrincipal$ruta');
    final uri2 = Uri.parse('$_urlAlterna$ruta');

    http.Response res;
    try {
      if (metodo == 'GET') {
        res = await http.get(uri1, headers: _headers);
        if (res.statusCode == 404) {
          res = await http.get(uri2, headers: _headers);
        }
      } else if (metodo == 'POST') {
        res = await http.post(uri1, headers: _headers, body: body != null ? jsonEncode(body) : null);
        if (res.statusCode == 404) {
          res = await http.post(uri2, headers: _headers, body: body != null ? jsonEncode(body) : null);
        }
      } else {
        throw Exception('Método HTTP no soportado: $metodo');
      }
      return res;
    } catch (_) {
      // Reintentar en uri2 si falló la conexión inicial
      if (metodo == 'GET') {
        return await http.get(uri2, headers: _headers);
      } else {
        return await http.post(uri2, headers: _headers, body: body != null ? jsonEncode(body) : null);
      }
    }
  }

  /// Lista los apadrinamientos activos para el panel del administrador.
  static Future<List<ApadrinamientoActivoSeguimiento>> listarApadrinamientosActivos() async {
    final res = await _peticionConFallback('GET', '/activos');
    if (res.statusCode != 200) {
      String error = 'Error al cargar apadrinamientos activos';
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['error'] != null) error = data['error'].toString();
      } catch (_) {}
      throw Exception(error);
    }

    final List lista = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return lista
        .map((j) => ApadrinamientoActivoSeguimiento.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene el historial de seguimientos de una solicitud de apadrinamiento.
  static Future<List<SeguimientoApadrinamientoItem>> obtenerHistorial(String idSolicitud) async {
    final res = await _peticionConFallback('GET', '/historial/$idSolicitud');
    if (res.statusCode != 200) {
      String error = 'Error al cargar el historial de seguimientos';
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['error'] != null) error = data['error'].toString();
      } catch (_) {}
      throw Exception(error);
    }

    final List lista = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return lista
        .map((j) => SeguimientoApadrinamientoItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Registra un nuevo seguimiento de apadrinamiento.
  /// El cumplimiento se calcula automáticamente: calificación >= 3 -> true, <= 2 -> false.
  static Future<Map<String, dynamic>> crearSeguimiento({
    required String idSolicitud,
    required int calificacion,
    bool? cumplimiento,
    required String observaciones,
    DateTime? proximoSeguimiento,
  }) async {
    String? proximoStr;
    if (proximoSeguimiento != null) {
      proximoStr = '${proximoSeguimiento.year.toString().padLeft(4, '0')}-'
          '${proximoSeguimiento.month.toString().padLeft(2, '0')}-'
          '${proximoSeguimiento.day.toString().padLeft(2, '0')}';
    }

    final bool cumpleFinal = cumplimiento ?? (calificacion >= 3);

    final body = {
      'id_solicitud_apadrinamiento': idSolicitud,
      'calificacion': calificacion,
      'cumplimiento': cumpleFinal,
      'observaciones': observaciones.trim(),
      'proximo_seguimiento': proximoStr,
    };

    final res = await _peticionConFallback('POST', '', body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      String error = 'Error al registrar el seguimiento';
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['error'] != null) error = data['error'].toString();
      } catch (_) {}
      throw Exception(error);
    }

    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Obtiene los próximos seguimientos programados para el calendario.
  static Future<List<ItemCalendarioSeguimiento>> obtenerCalendario() async {
    final res = await _peticionConFallback('GET', '/calendario');
    if (res.statusCode != 200) {
      String error = 'Error al cargar el calendario de seguimientos';
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['error'] != null) error = data['error'].toString();
      } catch (_) {}
      throw Exception(error);
    }

    final List lista = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return lista
        .map((j) => ItemCalendarioSeguimiento.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Cancela el apadrinamiento con motivo obligatorio e inhabilita al padrino para nuevos apadrinamientos.
  static Future<void> cancelarApadrinamientoPorIncumplimiento({
    required String idSolicitud,
    required String motivo,
  }) async {
    final body = {
      'id_solicitud_apadrinamiento': idSolicitud,
      'motivo': motivo.trim(),
    };

    final res = await _peticionConFallback('POST', '/cancelar', body: body);
    if (res.statusCode != 200) {
      String error = 'No se pudo cancelar el apadrinamiento';
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['error'] != null) error = data['error'].toString();
      } catch (_) {}
      throw Exception(error);
    }
  }

  /// Obtiene el resumen estadístico de un padrino (calificación promedio, advertencias, etc.).
  static Future<ResumenPadrino?> obtenerResumenPadrino(String idUsuario) async {
    if (idUsuario.isEmpty) return null;
    try {
      final res = await _peticionConFallback('GET', '/padrino/$idUsuario/resumen');
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return ResumenPadrino.fromJson(data);
      }
    } catch (_) {}
    return null;
  }
}
