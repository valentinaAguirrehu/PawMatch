import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

final http.Client cliente = BrowserClient()..withCredentials = true;

void recordarSesion(String? token) {}

Map<String, String> conSesion(Map<String, String>? headers) => headers ?? {};
