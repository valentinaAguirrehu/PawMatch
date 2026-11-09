import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      } else if (metodo == 'PUT') {
        res = await http.put(uri1, headers: _headers, body: body != null ? jsonEncode(body) : null);
        if (res.statusCode == 404) {
          res = await http.put(uri2, headers: _headers, body: body != null ? jsonEncode(body) : null);
        }
      } else {
        throw Exception('Método HTTP no soportado: $metodo');
      }
      return res;
    } catch (_) {
      // Reintentar en uri2 si falló la conexión inicial
      if (metodo == 'GET') {
        return await http.get(uri2, headers: _headers);
      } else if (metodo == 'POST') {
        return await http.post(uri2, headers: _headers, body: body != null ? jsonEncode(body) : null);
      } else if (metodo == 'PUT') {
        return await http.put(uri2, headers: _headers, body: body != null ? jsonEncode(body) : null);
      } else {
        rethrow;
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

    final dynamic bodyDecoded = jsonDecode(utf8.decode(res.bodyBytes));
    final List lista;
    if (bodyDecoded is Map && bodyDecoded['seguimientos'] is List) {
      lista = bodyDecoded['seguimientos'] as List;
    } else if (bodyDecoded is List) {
      lista = bodyDecoded;
    } else {
      lista = [];
    }

    return lista
        .map((j) => SeguimientoApadrinamientoItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Registra un nuevo seguimiento de apadrinamiento con aportes revisados opcionales.
  static Future<Map<String, dynamic>> crearSeguimiento({
    required String idSolicitud,
    required int calificacion,
    bool? cumplimiento,
    required String observaciones,
    DateTime? proximoSeguimiento,
    List<SeguimientoAporteItem>? aportes,
  }) async {
    String? proximoStr;
    if (proximoSeguimiento != null) {
      proximoStr = '${proximoSeguimiento.year.toString().padLeft(4, '0')}-'
          '${proximoSeguimiento.month.toString().padLeft(2, '0')}-'
          '${proximoSeguimiento.day.toString().padLeft(2, '0')}';
    }

    final bool cumpleFinal = cumplimiento ?? (calificacion >= 3);

    final Map<String, dynamic> body = {
      'id_solicitud_apadrinamiento': idSolicitud,
      'calificacion': calificacion,
      'cumplimiento': cumpleFinal,
      'observaciones': observaciones.trim(),
      'proximo_seguimiento': proximoStr,
    };

    if (aportes != null && aportes.isNotEmpty) {
      body['aportes'] = aportes.map((a) => a.toJson()).toList();
    }

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

  /// Cancela el apadrinamiento con motivo obligatorio y bloqueo opcional.
  static Future<void> cancelarApadrinamientoPorIncumplimiento({
    required String idSolicitud,
    required String motivo,
    bool bloquearUsuario = true,
  }) async {
    final body = {
      'id_solicitud_apadrinamiento': idSolicitud,
      'motivo': motivo.trim(),
      'bloquear_usuario': bloquearUsuario,
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
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map<String, dynamic>) {
          return ResumenPadrino.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Registra la evaluación/decisión del administrador ('continuar' o 'cancelar')
  /// cierra el ciclo evaluado e inicia el siguiente en 0/3.
  static Future<Map<String, dynamic>> registrarEvaluacion({
    required String idSolicitud,
    required String decision, // 'continuar' | 'cancelar'
    String? nota,
    int? ciclo,
    bool bloquearUsuario = false,
  }) async {
    final Map<String, dynamic> body = {
      'id_solicitud_apadrinamiento': idSolicitud,
      'decision': decision,
      'nota': nota?.trim(),
      'bloquear_usuario': bloquearUsuario,
    };
    if (ciclo != null) body['ciclo'] = ciclo;

    try {
      final res = await _peticionConFallback('POST', '/evaluar', body: body);
      final rawBody = utf8.decode(res.bodyBytes);

      if (res.statusCode != 200 && res.statusCode != 201) {
        String errorDetallado = 'Error al registrar la evaluación';
        try {
          final data = jsonDecode(rawBody);
          if (data is Map) {
            errorDetallado = data['error']?.toString() ??
                data['message']?.toString() ??
                errorDetallado;
          }
        } catch (_) {}
        throw Exception(errorDetallado);
      }

      final data = jsonDecode(rawBody);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (e) {
      debugPrint('[REGISTRAR EVALUACION EXCEPTION]: $e');
      rethrow;
    }
  }

  /// Marca una evaluación de ciclo como vista por el usuario padrino para apagar el punto de notificación.
  static Future<void> marcarReporteVisto(String idEvaluacion) async {
    if (idEvaluacion.isEmpty) return;
    try {
      await _peticionConFallback('PUT', '/reporte-visto/$idEvaluacion');
    } catch (e) {
      debugPrint('[MARCAR REPORTE VISTO ERROR]: $e');
    }
  }
}
