import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:paw_match/models/denuncia.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';

class DenunciasService {
  DenunciasService._();

  static final ValueNotifier<int> noLeidasAdmin = ValueNotifier<int>(0);
  static final ValueNotifier<int> pendientesAdmin = ValueNotifier<int>(0);
  static Timer? _timerNotificaciones;

  static String get _url => '${ApiService.baseUrl}/denuncias';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-usuario-id': Session.idUsuario ?? '',
  };

  /// Inicia el monitoreo periódico de denuncias para administradores.
  static void iniciarMonitoreo() {
    actualizarConteo();
    _timerNotificaciones?.cancel();
    _timerNotificaciones = Timer.periodic(
      const Duration(seconds: 30),
      (_) => actualizarConteo(),
    );
  }

  /// Detiene el temporizador de monitoreo.
  static void detenerMonitoreo() {
    _timerNotificaciones?.cancel();
    _timerNotificaciones = null;
  }

  /// Consulta el conteo de denuncias no leídas y pendientes.
  static Future<void> actualizarConteo() async {
    if (!Session.esAdmin) return;
    try {
      final res = await http.get(
        Uri.parse('$_url/conteo-pendientes'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        noLeidasAdmin.value = (data['no_leidas'] as int?) ?? 0;
        pendientesAdmin.value = (data['pendientes'] as int?) ?? 0;
      }
    } catch (_) {}
  }

  /// Envía una nueva denuncia ciudadana con sus archivos de evidencias.
  static Future<Map<String, dynamic>> enviarDenuncia({
    required String nombreReportante,
    required String telefonoReportante,
    required String barrioReportante,
    String ciudadReportante = 'San Juan de Pasto',
    required String tipoReporte,
    required String tipoAnimal,
    required String ubicacionAnimal,
    required String ciudadCaso,
    required String fechaSituacion,
    required String peligroInmediato,
    required String descripcionCaso,
    String? caracteristicasAnimal,
    String? estadoSalud,
    String? heridasVisibles,
    String? condicionesAlimentacion,
    String? condicionesLugar,
    String? comportamientoAnimal,
    String? dificultadMovilidad,
    String? observacionesAdicionales,
    required bool aceptoPolitica,
    List<({Uint8List bytes, String nombre})> archivos = const [],
  }) async {
    final uri = Uri.parse(_url);
    final req = http.MultipartRequest('POST', uri);

    if (Session.idUsuario != null && Session.idUsuario!.isNotEmpty) {
      req.headers['x-usuario-id'] = Session.idUsuario!;
    }

    req.fields['nombre_reportante'] = nombreReportante.trim();
    req.fields['telefono_reportante'] = telefonoReportante.trim();
    req.fields['barrio_reportante'] = barrioReportante.trim();
    req.fields['ciudad_reportante'] = ciudadReportante.trim();

    req.fields['tipo_reporte'] = tipoReporte.trim();
    req.fields['tipo_animal'] = tipoAnimal.trim();
    req.fields['ubicacion_animal'] = ubicacionAnimal.trim();
    req.fields['ciudad_caso'] = ciudadCaso.trim();
    req.fields['fecha_situacion'] = fechaSituacion.trim();
    req.fields['peligro_inmediato'] = peligroInmediato.trim();
    req.fields['descripcion_caso'] = descripcionCaso.trim();

    if (caracteristicasAnimal != null && caracteristicasAnimal.trim().isNotEmpty) {
      req.fields['caracteristicas_animal'] = caracteristicasAnimal.trim();
    }
    if (estadoSalud != null && estadoSalud.trim().isNotEmpty) {
      req.fields['estado_salud'] = estadoSalud.trim();
    }
    if (heridasVisibles != null && heridasVisibles.trim().isNotEmpty) {
      req.fields['heridas_visibles'] = heridasVisibles.trim();
    }
    if (condicionesAlimentacion != null && condicionesAlimentacion.trim().isNotEmpty) {
      req.fields['condiciones_alimentacion'] = condicionesAlimentacion.trim();
    }
    if (condicionesLugar != null && condicionesLugar.trim().isNotEmpty) {
      req.fields['condiciones_lugar'] = condicionesLugar.trim();
    }
    if (comportamientoAnimal != null && comportamientoAnimal.trim().isNotEmpty) {
      req.fields['comportamiento_animal'] = comportamientoAnimal.trim();
    }
    if (dificultadMovilidad != null && dificultadMovilidad.trim().isNotEmpty) {
      req.fields['dificultad_movilidad'] = dificultadMovilidad.trim();
    }
    if (observacionesAdicionales != null && observacionesAdicionales.trim().isNotEmpty) {
      req.fields['observaciones_adicionales'] = observacionesAdicionales.trim();
    }
    req.fields['acepto_politica'] = aceptoPolitica.toString();

    // Adjuntar evidencias
    for (final arch in archivos) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'archivos',
          arch.bytes,
          filename: arch.nombre,
        ),
      );
    }

    final streamed = await req.send().timeout(const Duration(seconds: 40));
    final res = await http.Response.fromStream(streamed);

    String bodyStr = '';
    try {
      bodyStr = utf8.decode(res.bodyBytes);
    } catch (_) {
      bodyStr = res.body;
    }

    dynamic data;
    try {
      data = jsonDecode(bodyStr);
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {'ok': true};
    } else {
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Error al enviar el reporte de la denuncia';
      throw Exception(msg);
    }
  }

  /// Lista denuncias para el panel de administración con control de timeout.
  static Future<List<Denuncia>> listarParaAdmin({String? estado, String? query}) async {
    final queryParams = <String, String>{};
    if (estado != null && estado.isNotEmpty) queryParams['estado'] = estado;
    if (query != null && query.isNotEmpty) queryParams['q'] = query;

    final uri = Uri.parse(_url).replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      String msg = 'Error al cargar la lista de denuncias';
      try {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d['error'] != null) msg = d['error'];
      } catch (_) {}
      throw Exception(msg);
    }

    final List lista = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return lista.map((j) => Denuncia.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Consulta el detalle completo de una denuncia (la marca como leída).
  static Future<DenunciaDetalle> obtenerDetalle(String id) async {
    final uri = Uri.parse('$_url/$id');
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      String msg = 'Error al consultar el detalle de la denuncia';
      try {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d['error'] != null) msg = d['error'];
      } catch (_) {}
      throw Exception(msg);
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    actualizarConteo();
    return DenunciaDetalle.fromJson(data);
  }

  /// Actualiza el estado y las observaciones internas de una denuncia.
  static Future<void> actualizarEstado({
    required String id,
    required String nuevoEstado,
    String? observacionesInternas,
    String? accionesRealizadas,
  }) async {
    final uri = Uri.parse('$_url/$id/estado');
    final res = await http.put(
      uri,
      headers: _headers,
      body: jsonEncode({
        'estado': nuevoEstado,
        'observaciones_internas': observacionesInternas,
        'acciones_realizadas': accionesRealizadas,
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      String msg = 'Error al actualizar el estado';
      try {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d['error'] != null) msg = d['error'];
      } catch (_) {}
      throw Exception(msg);
    }
    actualizarConteo();
  }

  /// Reintenta el envío de la notificación por correo al administrador.
  static Future<void> reintentarCorreo(String id) async {
    final uri = Uri.parse('$_url/$id/reintentar-correo');
    final res = await http.post(uri, headers: _headers).timeout(const Duration(seconds: 25));

    if (res.statusCode != 200) {
      String msg = 'Error al reenviar el correo';
      try {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d['error'] != null) msg = d['error'];
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// URL para streaming seguro de archivo.
  static String getUrlArchivo(String idDenuncia, String idArchivo) {
    final adminId = Session.idUsuario ?? '';
    return '$_url/$idDenuncia/archivos/$idArchivo?adminId=$adminId';
  }

  /// Descarga los bytes de un archivo adjunto con autenticación de administrador y timeout.
  static Future<Uint8List> descargarArchivoBytes(String idDenuncia, String idArchivo) async {
    final uri = Uri.parse(getUrlArchivo(idDenuncia, idArchivo));
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    throw Exception('No se pudo descargar el archivo de evidencia');
  }
}
