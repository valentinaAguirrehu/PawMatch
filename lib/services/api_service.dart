import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:paw_match/models/admin_user.dart';
import 'package:paw_match/models/user.dart';
import 'package:paw_match/services/session.dart';

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
    required DateTime fechaNacimiento,
  }) async {
    final fecha =
        '${fechaNacimiento.year.toString().padLeft(4, '0')}-'
        '${fechaNacimiento.month.toString().padLeft(2, '0')}-'
        '${fechaNacimiento.day.toString().padLeft(2, '0')}';
    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/registro'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombres': nombres,
        'apellidos': apellidos,
        'correo': correo,
        'telefono': telefono,
        'contrasena': contrasena,
        'fecha_nacimiento': fecha,
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

  static Future<User> obtenerUsuario(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/usuarios/$id'));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return User.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(data['error'] ?? 'No se pudo cargar el perfil');
  }

  static Future<User> actualizarUsuario(User usuario) async {
    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/${usuario.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(usuario.toJson()),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return User.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(data['error'] ?? 'No se pudo guardar el perfil');
  }

  static Future<void> cambiarContrasena({
    required String id,
    required String contrasena,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$id/contrasena'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contrasena': contrasena}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'No se pudo actualizar la contraseña');
    }
  }

  static Future<List<AdminUser>> listarUsuariosAdmin({
    required String rol,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/admin/usuarios',
    ).replace(queryParameters: {'rol': rol});
    final response = await http.get(
      uri,
      headers: {'x-usuario-id': Session.idUsuario ?? ''},
    );
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json')) {
      throw Exception(
        'La API respondió HTTP ${response.statusCode} sin JSON en $uri. '
        'Verifica que la aplicación y el backend estén usando el mismo servidor.',
      );
    }
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data as List<dynamic>)
          .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
      (data as Map<String, dynamic>)['error'] ??
          'No se pudieron cargar las cuentas',
    );
  }

  static Future<AdminUser> cambiarEstadoUsuarioAdmin({
    required String id,
    required bool activo,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/usuarios/$id/estado'),
      headers: {
        'Content-Type': 'application/json',
        'x-usuario-id': Session.idUsuario ?? '',
      },
      body: jsonEncode({'estado_cuenta': activo ? 'activo' : 'inactivo'}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return AdminUser.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(
      (data as Map<String, dynamic>)['error'] ??
          'No se pudo actualizar la cuenta',
    );
  }

  static Future<AdminUser> crearAdministrador({
    required String nombres,
    required String apellidos,
    required String correo,
    required String telefono,
    required String contrasena,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/usuarios/administradores'),
      headers: {
        'Content-Type': 'application/json',
        'x-usuario-id': Session.idUsuario ?? '',
      },
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
      return AdminUser.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(
      (data as Map<String, dynamic>)['error'] ??
          'No se pudo crear el administrador',
    );
  }

  static Future<String> subirFotoPerfil(
    Uint8List bytes,
    String nombreArchivo,
  ) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/usuarios/foto'),
    );
    req.headers['x-usuario-id'] = Session.idUsuario ?? '';
    req.files.add(
      http.MultipartFile.fromBytes('foto', bytes, filename: nombreArchivo),
    );
    final response = await http.Response.fromStream(await req.send());
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return (data as Map<String, dynamic>)['ruta'] as String;
    }
    throw Exception(data['error'] ?? 'No se pudo subir la foto');
  }
}
