import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:paw_match/models/adoption_request.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';

class AdoptionService {
  AdoptionService._();

  static String get _url => '${ApiService.baseUrl}/adoption-requests';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-usuario-id': Session.idUsuario ?? '',
  };

  /// Envía el formulario de adopción con la cédula y el recibo.
  static Future<void> submit({
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
  }) async {
    final res = await http.put(
      Uri.parse('$_url/$id/status'),
      headers: _headers,
      body: jsonEncode({'estado': status}),
    );
    if (res.statusCode != 200) {
      throw Exception(_mensaje(res, 'No se pudo actualizar la solicitud'));
    }
  }

  static Future<Uint8List> fetchIdCard(String id) =>
      _archivo('$_url/$id/id-card');

  static Future<Uint8List> fetchUtilityBill(String id) =>
      _archivo('$_url/$id/utility-bill');

  static Future<Uint8List> _archivo(String url) async {
    final res = await http.get(Uri.parse(url), headers: _headers);
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
