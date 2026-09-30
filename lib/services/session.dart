/// Guarda en memoria al usuario que inició sesión.
/// (Si cierras la app hay que volver a iniciar sesión.)
class Session {
  static String? idUsuario;
  static String nombre = '';
  static String rol = 'usuario';

  static bool get isAdmin => rol == 'administrador';

  /// Recibe el JSON que devuelve POST /api/usuarios/login
  static void iniciar(Map<String, dynamic> usuario) {
    idUsuario = usuario['id_usuario']?.toString();
    nombre = (usuario['nombres'] ?? '').toString();
    rol = (usuario['rol'] ?? 'usuario').toString();
  }

  static void cerrar() {
    idUsuario = null;
    nombre = '';
    rol = 'usuario';
  }
}
