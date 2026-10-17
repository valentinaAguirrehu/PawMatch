import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:paw_match/models/solicitud_apadrinamiento.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';

class ApadrinamientoService {
  ApadrinamientoService._();

  static final ValueNotifier<int> noLeidasAdmin = ValueNotifier<int>(0);
  static final ValueNotifier<int> noLeidasUsuario = ValueNotifier<int>(0);
  static Timer? _timerNotificaciones;

  static String get _url => '${ApiService.baseUrl}/solicitudes-apadrinamiento';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-usuario-id': Session.idUsuario ?? '',
  };

  /// Envía una nueva solicitud de apadrinamiento con la foto del documento.
  static Future<void> enviarSolicitud({
    required String idMascota,
    required String motivacion,
    int? montoAporte,
    String frecuenciaAporte = 'mensual',
    required Uint8List bytesDocumento,
    required String nombreArchivo,
  }) async {
    final uri = Uri.parse(_url);
    final req = http.MultipartRequest('POST', uri);

    req.headers['x-usuario-id'] = Session.idUsuario ?? '';
    req.fields['id_mascota'] = idMascota;
    req.fields['informacion_adicional'] = motivacion;
    req.fields['acuerdo_responsabilidad'] = 'true';
    req.fields['frecuencia_aporte'] = frecuenciaAporte;
    if (montoAporte != null && montoAporte > 0) {
      req.fields['monto_aporte'] = montoAporte.toString();
    }

    req.files.add(
      http.MultipartFile.fromBytes(
        'documento',
        bytesDocumento,
        filename: nombreArchivo,
      ),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200 && res.statusCode != 201) {
      String mensaje = 'No se pudo enviar la solicitud';
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['error'] != null) {
          mensaje = data['error'].toString();
        }
      } catch (_) {}
      throw Exception(mensaje);
    }
  }

  /// Lista solicitudes para el panel del administrador.
  static Future<List<SolicitudApadrinamiento>> listarParaAdmin({String? estado}) async {
    final uri = Uri.parse(_url).replace(
      queryParameters: estado != null && estado.isNotEmpty ? {'estado': estado} : null,
    );

    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Error al cargar las solicitudes de apadrinamiento');
    }

    final List lista = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return lista.map((j) => SolicitudApadrinamiento.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Lista las solicitudes del usuario logueado.
  static Future<List<SolicitudApadrinamiento>> listarMisSolicitudes({String? idMascota}) async {
    final params = {'mis_solicitudes': 'true'};
    if (idMascota != null && idMascota.isNotEmpty) {
      params['mascota_id'] = idMascota;
    }

    final uri = Uri.parse(_url).replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Error al cargar tus solicitudes');
    }

    final List lista = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return lista.map((j) => SolicitudApadrinamiento.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Actualiza el estado de la solicitud (Aprobar o Rechazar).
  static Future<void> actualizarEstado({
    required String idSolicitud,
    required String estado, // 'aprobada' o 'rechazada'
    String? fechaInicio,
    String? observaciones,
  }) async {
    final uri = Uri.parse('$_url/$idSolicitud/estado');
    final body = jsonEncode({
      'estado': estado,
      if (fechaInicio != null) 'fecha_inicio_apadrinamiento': fechaInicio,
      if (observaciones != null) 'observaciones': observaciones,
    });

    final res = await http.put(uri, headers: _headers, body: body);
    if (res.statusCode != 200) {
      String mensaje = 'No se pudo actualizar la solicitud';
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['error'] != null) {
          mensaje = data['error'].toString();
        }
      } catch (_) {}
      throw Exception(mensaje);
    }
  }

  /// Descarga segura de los bytes del documento de identidad.
  static Future<Uint8List> obtenerBytesDocumento(String idSolicitud) async {
    final uri = Uri.parse('$_url/$idSolicitud/documento');
    final res = await http.get(uri, headers: _headers);

    if (res.statusCode != 200) {
      throw Exception('No tienes autorización o el documento no existe');
    }
    return res.bodyBytes;
  }

  /// Inicia monitoreo en segundo plano de notificaciones.
  static void iniciarMonitoreo() {
    _timerNotificaciones?.cancel();
    actualizarNotificaciones();
    _timerNotificaciones = Timer.periodic(const Duration(seconds: 12), (_) {
      actualizarNotificaciones();
    });
  }

  /// Detiene el monitoreo al cerrar sesión.
  static void detenerMonitoreo() {
    _timerNotificaciones?.cancel();
    _timerNotificaciones = null;
    noLeidasAdmin.value = 0;
    noLeidasUsuario.value = 0;
  }

  /// Consulta el resumen de notificaciones desde el backend y actualiza notifiers.
  static Future<void> actualizarNotificaciones() async {
    final id = Session.idUsuario;
    if (id == null || id.isEmpty) return;
    try {
      final uri = Uri.parse('$_url/notificaciones/resumen');
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map) {
          noLeidasAdmin.value = int.tryParse(data['totalAdmin']?.toString() ?? '0') ?? 0;
          noLeidasUsuario.value = int.tryParse(data['totalUsuario']?.toString() ?? '0') ?? 0;
        }
      }
    } catch (_) {}
  }

  /// Marca como leídas las solicitudes por el admin.
  static Future<void> marcarLeidasAdmin() async {
    try {
      final uri = Uri.parse('$_url/notificaciones/marcar-admin');
      await http.put(uri, headers: _headers);
      noLeidasAdmin.value = 0;
    } catch (_) {}
  }

  /// Marca como leídas las notificaciones por el usuario.
  static Future<void> marcarLeidasUsuario() async {
    try {
      final uri = Uri.parse('$_url/notificaciones/marcar-usuario');
      await http.put(uri, headers: _headers);
      noLeidasUsuario.value = 0;
    } catch (_) {}
  }
}
