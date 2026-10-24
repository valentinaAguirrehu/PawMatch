import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';

class AdoptionService {
  AdoptionService._();

  static final ValueNotifier<int> noLeidasAdmin = ValueNotifier<int>(0);
  static final ValueNotifier<int> noLeidasUsuario = ValueNotifier<int>(0);
  static Timer? _timerNotificaciones;

  static String get _url => '${ApiService.baseUrl}/adoption-requests';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-usuario-id': Session.idUsuario ?? '',
  };

  /// Envía el formulario de adopción con la cédula y el recibo.
  /// Devuelve el id de la solicitud creada para consignarlo en el acta PDF.
  static Future<String?> submit({
    required String petId,
    required String housingType,
    required bool hasYard,
    required bool hasChildren,
    required bool hasOtherPets,
    String? otherPets,
    required String availableTime,
    required bool previousExperience,
    required String additionalInfo,
    required Uint8List idCardBytes,
    required String idCardName,
    required Uint8List utilityBillBytes,
    required String utilityBillName,
    String? correoContacto,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse(_url));
    req.headers['x-usuario-id'] = Session.idUsuario ?? '';
    req.fields.addAll({
      'id_mascota': petId,
      'tipo_vivienda': housingType,
      'tiene_patio': hasYard.toString(),
      'tiene_ninos': hasChildren.toString(),
      'tiene_mascotas': hasOtherPets.toString(),
      'tiempo_disponible': availableTime,
      'experiencia_previa': previousExperience.toString(),
      'informacion_adicional': additionalInfo,
      if (hasOtherPets && otherPets != null) 'otras_mascotas': otherPets,
      if (correoContacto != null && correoContacto.trim().isNotEmpty)
        'correo_contacto': correoContacto.trim(),
    });
    req.files.add(
      http.MultipartFile.fromBytes(
        'foto_cedula',
        idCardBytes,
        filename: idCardName,
      ),
    );
    req.files.add(
      http.MultipartFile.fromBytes(
        'foto_servicios_publicos',
        utilityBillBytes,
        filename: utilityBillName,
      ),
    );

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_mensaje(res, 'No se pudo enviar la solicitud'));
    }

    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map && data['id_solicitud_adopcion'] != null) {
        return data['id_solicitud_adopcion'].toString();
      }
    } catch (_) {}
    return null;
  }

  static Future<List<AdoptionRequest>> listForAdmin() async {
    final res = await http.get(Uri.parse(_url), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception(_mensaje(res, 'Error al cargar las solicitudes de adopción'));
    }
    return _lista(res);
  }

  static Future<List<AdoptionRequest>> listMine({String? petId}) async {
    final params = {'mine': 'true'};
    if (petId != null && petId.isNotEmpty) params['pet_id'] = petId;
    final uri = Uri.parse(_url).replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception(_mensaje(res, 'Error al cargar tus solicitudes'));
    }
    return _lista(res);
  }

  /// [status] es `aprobada` o `rechazada`.
  static Future<void> updateStatus({
    required String id,
    required String status,
    String? startDate,
    String? observations,
  }) async {
    final res = await http.put(
      Uri.parse('$_url/$id/status'),
      headers: _headers,
      body: jsonEncode({
        'estado': status,
        if (startDate != null) 'fecha_inicio_adopcion': startDate,
        if (observations != null) 'observaciones': observations,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception(_mensaje(res, 'No se pudo actualizar la solicitud'));
    }
  }

  /// Consulta cada 12 segundos si hay solicitudes nuevas o respuestas sin leer.
  static void iniciarMonitoreo() {
    _timerNotificaciones?.cancel();
    actualizarNotificaciones();
    _timerNotificaciones = Timer.periodic(const Duration(seconds: 12), (_) {
      actualizarNotificaciones();
    });
  }

  static void detenerMonitoreo() {
    _timerNotificaciones?.cancel();
    _timerNotificaciones = null;
    noLeidasAdmin.value = 0;
    noLeidasUsuario.value = 0;
  }

  static Future<void> actualizarNotificaciones() async {
    final id = Session.idUsuario;
    if (id == null || id.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse('$_url/notificaciones/resumen'),
        headers: _headers,
      );
      if (res.statusCode != 200) return;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is! Map) return;
      noLeidasAdmin.value = int.tryParse(data['totalAdmin']?.toString() ?? '0') ?? 0;
      noLeidasUsuario.value =
          int.tryParse(data['totalUsuario']?.toString() ?? '0') ?? 0;
    } catch (_) {}
  }

  static Future<void> marcarLeidasAdmin() async {
    try {
      await http.put(
        Uri.parse('$_url/notificaciones/marcar-admin'),
        headers: _headers,
      );
      noLeidasAdmin.value = 0;
    } catch (_) {}
  }

  static Future<void> marcarLeidasUsuario() async {
    try {
      await http.put(
        Uri.parse('$_url/notificaciones/marcar-usuario'),
        headers: _headers,
      );
      noLeidasUsuario.value = 0;
    } catch (_) {}
  }

  /// Sube el contrato firmado. Solo un administrador puede llamarlo.
  static Future<void> subirContrato({
    required String id,
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_url/$id/contrato'));
    req.headers['x-usuario-id'] = Session.idUsuario ?? '';
    req.files.add(
      http.MultipartFile.fromBytes('contrato', bytes, filename: nombreArchivo),
    );
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_mensaje(res, 'No se pudo subir el contrato'));
    }
  }

  static Future<Uint8List> fetchContract(String id) =>
      _archivo('$_url/$id/contrato');

  /// Quita el contrato. La solicitud aprobada vuelve a quedar pendiente de carga.
  static Future<void> eliminarContrato(String id) async {
    var res = await http.delete(Uri.parse('$_url/$id/contrato'), headers: _headers);
    if (res.statusCode == 404 || res.statusCode == 405) {
      res = await http.post(
        Uri.parse('$_url/$id/contrato/eliminar'),
        headers: _headers,
      );
    }
    if (res.statusCode != 200) {
      throw Exception(_mensaje(res, 'No se pudo eliminar el contrato'));
    }
  }

  static Future<Uint8List> fetchIdCard(String id) =>
      _archivo('$_url/$id/id-card');

  static Future<Uint8List> fetchUtilityBill(String id) =>
      _archivo('$_url/$id/utility-bill');

  static Future<Uint8List> _archivo(String url) async {
    final res = await http
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception(_mensaje(res, 'No se pudo abrir el documento'));
    }
    return res.bodyBytes;
  }

  static List<AdoptionRequest> _lista(http.Response res) {
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return const [];
    return data
        .map((item) => AdoptionRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static String _mensaje(http.Response res, String fallback) {
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map && data['error'] != null) return data['error'].toString();
    } catch (_) {}
    return fallback;
  }
}
