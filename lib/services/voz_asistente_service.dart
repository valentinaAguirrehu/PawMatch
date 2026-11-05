import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una voz de la API de texto a voz de OpenAI.
class VozAsistente {
  const VozAsistente({
    required this.id,
    required this.nombre,
    required this.detalle,
  });

  final String id;
  final String nombre;
  final String detalle;
}

/// Preferencia de voz del asistente. La clave de OpenAI se queda en el servidor.
class VozAsistenteService {
  static const defecto = 'marin';
  static const _claveLocal = 'paw_voz_asistente';

  /// La voz ya guardada. Los formularios del asistente escuchan este valor.
  static final ValueNotifier<String> vozActual = ValueNotifier<String>(defecto);

  static const voces = <VozAsistente>[
    VozAsistente(id: 'marin', nombre: 'Marin', detalle: 'Cálida y clara'),
    VozAsistente(id: 'coral', nombre: 'Coral', detalle: 'Amable y cercana'),
    VozAsistente(id: 'nova', nombre: 'Nova', detalle: 'Brillante'),
    VozAsistente(id: 'shimmer', nombre: 'Shimmer', detalle: 'Suave'),
    VozAsistente(id: 'sage', nombre: 'Sage', detalle: 'Serena'),
    VozAsistente(id: 'alloy', nombre: 'Alloy', detalle: 'Neutra'),
    VozAsistente(id: 'echo', nombre: 'Echo', detalle: 'Nítida'),
    VozAsistente(id: 'ash', nombre: 'Ash', detalle: 'Serena y baja'),
    VozAsistente(id: 'ballad', nombre: 'Ballad', detalle: 'Expresiva'),
    VozAsistente(id: 'fable', nombre: 'Fable', detalle: 'Narrativa'),
    VozAsistente(id: 'onyx', nombre: 'Onyx', detalle: 'Grave'),
    VozAsistente(id: 'verse', nombre: 'Verse', detalle: 'Versátil'),
    VozAsistente(id: 'cedar', nombre: 'Cedar', detalle: 'Firme'),
  ];

  static bool esValida(String? id) =>
      voces.any((voz) => voz.id == (id ?? '').trim().toLowerCase());

  static String nombre(String id) {
    for (final voz in voces) {
      if (voz.id == id) return voz.nombre;
    }
    return 'Marin';
  }

  static void _publicar(String voz) {
    if (vozActual.value != voz) vozActual.value = voz;
  }

  static String _idSesion() {
    final id = Session.idUsuario;
    if (id == null || id.isEmpty) {
      throw Exception('Inicia sesión para elegir la voz del asistente');
    }
    return id;
  }

  /// Voz guardada en el teléfono. Si aún no hay una, la pide al servidor.
  static Future<String> vozGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_claveLocal);
    if (esValida(local)) {
      final voz = local!.trim().toLowerCase();
      _publicar(voz);
      return voz;
    }
    if (!Session.estaLogueado) return defecto;
    try {
      final remota = await _leerRemota();
      await prefs.setString(_claveLocal, remota);
      _publicar(remota);
      return remota;
    } catch (_) {
      return defecto;
    }
  }

  static Future<String> _leerRemota() async {
    final id = _idSesion();
    final resp = await http.get(
      Uri.parse('${ApiService.baseUrl}/usuarios/$id/voz-asistente'),
      headers: {'x-usuario-id': id},
    );
    if (resp.statusCode != 200) {
      throw Exception(_mensaje(resp.body, 'No se pudo leer la voz'));
    }
    final data = jsonDecode(resp.body);
    final voz = data is Map ? data['voz']?.toString() : null;
    return esValida(voz) ? voz!.trim().toLowerCase() : defecto;
  }

  /// Guarda la voz en el teléfono y en la cuenta del usuario.
  static Future<void> guardar(String voz) async {
    final elegida = voz.trim().toLowerCase();
    if (!esValida(elegida)) {
      throw Exception('Esa voz no está disponible');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveLocal, elegida);
    _publicar(elegida);
    if (!Session.estaLogueado) return;
    final id = _idSesion();
    final resp = await http.put(
      Uri.parse('${ApiService.baseUrl}/usuarios/$id/voz-asistente'),
      headers: {
        'Content-Type': 'application/json',
        'x-usuario-id': id,
      },
      body: jsonEncode({'voz': elegida}),
    );
    if (resp.statusCode != 200) {
      throw Exception(_mensaje(resp.body, 'No se pudo guardar la voz'));
    }
  }

  /// Pide al servidor un mp3 de muestra con la voz indicada.
  static Future<Uint8List> probar(String voz) {
    return _audio(
      ruta: 'probar',
      cuerpo: {'voz': voz.trim().toLowerCase()},
    );
  }

  /// Genera el audio del texto con la voz del usuario. Devuelve null si OpenAI no responde,
  /// para que el asistente pueda usar la voz del dispositivo.
  static Future<Uint8List?> sintetizar({
    required String texto,
    required String voz,
    double velocidad = 1,
  }) async {
    final limpio = texto.trim();
    if (limpio.isEmpty || !Session.estaLogueado) return null;
    try {
      return await _audio(
        ruta: 'hablar',
        cuerpo: {
          'texto': limpio.length > 3500 ? limpio.substring(0, 3500) : limpio,
          'voz': voz.trim().toLowerCase(),
          'velocidad': velocidad,
        },
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> _audio({
    required String ruta,
    required Map<String, dynamic> cuerpo,
  }) async {
    final id = _idSesion();
    final resp = await http.post(
      Uri.parse('${ApiService.baseUrl}/usuarios/$id/voz-asistente/$ruta'),
      headers: {
        'Content-Type': 'application/json',
        'x-usuario-id': id,
      },
      body: jsonEncode(cuerpo),
    );
    final tipo = resp.headers['content-type'] ?? '';
    if (resp.statusCode != 200 || !tipo.contains('audio')) {
      throw Exception(_mensaje(resp.body, 'No se pudo generar la voz'));
    }
    return resp.bodyBytes;
  }

  static String _mensaje(String cuerpo, String respaldo) {
    try {
      final data = jsonDecode(cuerpo);
      if (data is Map && data['error'] is String && (data['error'] as String).isNotEmpty) {
        return data['error'] as String;
      }
    } catch (_) {}
    return respaldo;
  }
}
