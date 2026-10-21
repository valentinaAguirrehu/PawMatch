import 'package:paw_match/services/match_estado.dart';

/// Guarda en memoria al usuario que inició sesión.
/// (Si cierras la app hay que volver a iniciar sesión.)
class Session {
  static String? idUsuario;
  static String nombre = '';
  static String apellidos = '';
  static String correo = '';
  static String telefono = '';
  static String documentoIdentidad = '';
  static String rol = 'usuario';

  static bool get isAdmin => rol == 'administrador';
  static bool get esAdmin => isAdmin;

  /// Recibe el JSON que devuelve POST /api/usuarios/login
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
  }

  static void cerrar() {
    MatchEstado.instancia.reiniciar();
    idUsuario = null;
    nombre = '';
    apellidos = '';
    correo = '';
    telefono = '';
    documentoIdentidad = '';
    rol = 'usuario';
  }
}
