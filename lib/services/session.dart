import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paw_match/services/api_service.dart';
import 'package:paw_match/services/almacen_seguro.dart';
import 'package:paw_match/services/cliente_http.dart' as http;
import 'package:paw_match/services/match_estado.dart';

/// Guarda al usuario que inició sesión y persiste la sesión en almacenamiento local.
class Session {
  static String? idUsuario;
  static String nombre = '';
  static String apellidos = '';
  static String correo = '';
  static String telefono = '';
  static String documentoIdentidad = '';
  static String genero = '';
  static String rol = 'usuario';

  static bool get estaLogueado => idUsuario != null && idUsuario!.isNotEmpty;
  static String get _rolNormalizado => rol.trim().toLowerCase();
  static bool get esSuperAdmin => _rolNormalizado == 'superadmin';
  static bool get isAdmin =>
      _rolNormalizado == 'administrador' || esSuperAdmin;
  static bool get esAdmin => isAdmin;

  static const String _kKeyUsuario = 'paw_session_user';
  static const String _kKeyRecordar = 'paw_recordar_contrasena';
  static const String _kKeyCorreo = 'paw_correo_recordado';
  static const String _kKeyContrasena = 'paw_contrasena_recordada';

  /// Recibe el JSON que devuelve POST /api/usuarios/login y lo persiste
  static void iniciar(Map<String, dynamic> usuario) {
    idUsuario = usuario['id_usuario']?.toString();
    nombre = (usuario['nombres'] ?? '').toString();
    apellidos = (usuario['apellidos'] ?? '').toString();
    correo = (usuario['correo'] ?? '').toString();
    telefono = (usuario['telefono'] ?? '').toString();
    documentoIdentidad = (usuario['documento_identidad'] ??
            usuario['documentoIdentidad'] ??
            usuario['cedula'] ??
            '')
        .toString();
    genero = (usuario['genero'] ?? '').toString();
    rol = (usuario['rol'] ?? 'usuario').toString();

    // Guardar en almacenamiento local para no tener que iniciar sesión a cada rato
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kKeyUsuario, jsonEncode(usuario));
    }).catchError((_) {});
  }

  /// Actualiza el correo de la sesión y en la persistencia local
  static Future<void> actualizarCorreo(String nuevoCorreo) async {
    correo = nuevoCorreo.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyUsuario);
      if (str != null && str.isNotEmpty) {
        final map = jsonDecode(str);
        if (map is Map<String, dynamic>) {
          map['correo'] = correo;
          await prefs.setString(_kKeyUsuario, jsonEncode(map));
        }
      }
    } catch (_) {}
  }

  /// Restaura la sesión guardada previamente si existe.
  /// En celular exige el token del almacén seguro. En web usa la cookie.
  static Future<bool> restaurar() async {
    if (AlmacenSeguro.persisteToken) {
      final token = await AlmacenSeguro.leer();
      if (token == null || token.isEmpty) {
        await _limpiarUsuarioLocal();
        return false;
      }
      http.recordarSesion(token, persistir: true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kKeyUsuario);
      if (str == null || str.isEmpty) return false;
      final map = jsonDecode(str);
      if (map is Map<String, dynamic>) {
        idUsuario = map['id_usuario']?.toString();
        nombre = (map['nombres'] ?? '').toString();
        apellidos = (map['apellidos'] ?? '').toString();
        correo = (map['correo'] ?? '').toString();
        telefono = (map['telefono'] ?? '').toString();
        documentoIdentidad = (map['documento_identidad'] ??
                map['documentoIdentidad'] ??
                map['cedula'] ??
                '')
            .toString();
        genero = (map['genero'] ?? '').toString();
        rol = (map['rol'] ?? 'usuario').toString();
        return estaLogueado;
      }
    } catch (_) {}
    return false;
  }

  /// Guarda correo y contraseña del formulario cuando la persona marca recordar.
  static Future<void> guardarCredenciales({
    required bool recordar,
    required String correo,
    required String contrasena,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kKeyRecordar, recordar);
      if (recordar) {
        await prefs.setString(_kKeyCorreo, correo);
        await prefs.setString(_kKeyContrasena, contrasena);
      } else {
        await prefs.remove(_kKeyCorreo);
        await prefs.remove(_kKeyContrasena);
      }
    } catch (_) {}
  }

  /// Devuelve correo y contraseña guardados para volver a llenar el ingreso.
  static Future<({bool recordar, String correo, String contrasena})>
      obtenerCredencialesRecordadas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordar = prefs.getBool(_kKeyRecordar) ?? true;
      if (!recordar) {
        return (recordar: false, correo: '', contrasena: '');
      }
      return (
        recordar: true,
        correo: prefs.getString(_kKeyCorreo) ?? '',
        contrasena: prefs.getString(_kKeyContrasena) ?? '',
      );
    } catch (_) {
      return (recordar: true, correo: '', contrasena: '');
    }
  }

  /// Guarda el género en la sesión activa y en el almacenamiento local.
  static void fijarGenero(String valor) {
    genero = valor.trim();
    SharedPreferences.getInstance().then((prefs) {
      final str = prefs.getString(_kKeyUsuario);
      if (str == null || str.isEmpty) return;
      final map = jsonDecode(str);
      if (map is Map<String, dynamic>) {
        map['genero'] = genero;
        prefs.setString(_kKeyUsuario, jsonEncode(map));
      }
    }).catchError((_) {});
  }

  /// Cierra la sesión activa borrando la persistencia del usuario
  static void cerrar() {
    http.post(Uri.parse('${ApiService.baseUrl}/usuarios/logout')).then((_) {}, onError: (_) {});
    http.recordarSesion(null);
    MatchEstado.instancia.reiniciar();
    idUsuario = null;
    nombre = '';
    apellidos = '';
    correo = '';
    telefono = '';
    documentoIdentidad = '';
    genero = '';
    rol = 'usuario';

    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_kKeyUsuario);
    }).catchError((_) {});
  }

  static Future<void> _limpiarUsuarioLocal() async {
    idUsuario = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kKeyUsuario);
    } catch (_) {}
  }
}
