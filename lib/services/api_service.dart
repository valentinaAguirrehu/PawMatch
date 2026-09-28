import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  // Elige la URL según donde corra la app:
  // - Web (Chrome/Edge): localhost
  // - Emulador de Android: 10.0.2.2 apunta al localhost de tu PC
  // - Windows, macOS, Linux, iOS simulator: localhost
  // - Celular físico: cambia por la IP local de tu PC, ej: http://192.168.1.15:3000/api
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }

  static Future<Map<String, dynamic>> registrarUsuario({
    required String nombres,
    required String apellidos,
    required String correo,
    required String telefono,
    required String contrasena,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/registro'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombres': nombres,
        'apellidos': apellidos,
        'correo': correo,
        'telefono': telefono,
        'contrasena': contrasena,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data as Map<String, dynamic>;
    } else {
      throw Exception(data['error'] ?? 'Error al registrar el usuario');
    }
  }

  static Future<Map<String, dynamic>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'contrasena': contrasena}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    } else {
      throw Exception(data['error'] ?? 'Error al iniciar sesión');
    }
  }
}
