import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Android emulator -> 10.0.2.2 apunta al localhost de tu PC.
  // Dispositivo físico (celular real) -> usa la IP local de tu PC, ej: 192.168.1.15
  // iOS simulator -> localhost funciona directo.
  static const String baseUrl = 'http://10.0.2.2:3000/api';

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
}
