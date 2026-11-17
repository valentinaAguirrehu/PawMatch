import 'dart:convert';

import 'package:http/http.dart' as http;

final http.Client cliente = http.Client();
String? _token;

void recordarSesion(String? token) {
  _token = token;
}

Map<String, String> conSesion(Map<String, String>? headers) {
  final resultado = <String, String>{'X-Paw-Client': 'native', ...?headers};
  if (_token != null && _token!.isNotEmpty) {
    resultado['Authorization'] = 'Bearer $_token';
  }
  return resultado;
}
