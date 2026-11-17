import 'almacen_seguro_io.dart' if (dart.library.html) 'almacen_seguro_web.dart' as impl;

/// En celular guarda el identificador de sesión en el almacén del sistema.
/// En web no guarda nada: la sesión vive solo en la cookie HttpOnly.
class AlmacenSeguro {
  static bool get persisteToken => impl.persisteToken;

  static Future<void> guardar(String? token) => impl.guardar(token);

  static Future<String?> leer() => impl.leer();
}
