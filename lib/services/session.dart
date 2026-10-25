import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paw_match/services/match_estado.dart';

/// Guarda al usuario que inició sesión y persiste la sesión en almacenamiento local.
class Session {
  static String? idUsuario;
  static String nombre = '';
  static String apellidos = '';
  static String correo = '';
  static String telefono = '';
  static String documentoIdentidad = '';
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

  /// Restaura la sesión guardada previamente si existe
  static Future<bool> restaurar() async {
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
        rol = (map['rol'] ?? 'usuario').toString();
        return estaLogueado;
      }
    } catch (_) {}
    return false;
  }

  /// Guarda o borra las credenciales recordadas del formulario de login
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

  /// Obtiene las credenciales recordadas para el formulario de login
  static Future<({bool recordar, String correo, String contrasena})>
      obtenerCredencialesRecordadas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordar = prefs.getBool(_kKeyRecordar) ?? true;
      final c = prefs.getString(_kKeyCorreo) ?? '';
      final p = prefs.getString(_kKeyContrasena) ?? '';
      return (recordar: recordar, correo: c, contrasena: p);
    } catch (_) {
      return (recordar: true, correo: '', contrasena: '');
    }
  }

  /// Cierra la sesión activa borrando la persistencia del usuario
  static void cerrar() {
    MatchEstado.instancia.reiniciar();
    idUsuario = null;
    nombre = '';
    apellidos = '';
    correo = '';
    telefono = '';
    documentoIdentidad = '';
    rol = 'usuario';

    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_kKeyUsuario);
    }).catchError((_) {});
  }
}
