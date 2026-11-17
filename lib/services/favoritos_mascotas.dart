import 'package:flutter/foundation.dart';
import 'package:paw_match/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoritos de mascotas del usuario en sesión.
/// El inicio y la pestaña Mascotas leen y escriben esta misma lista.
class FavoritosMascotas {
  FavoritosMascotas._();

  /// El más reciente queda al inicio.
  static final ValueNotifier<List<String>> ids = ValueNotifier<List<String>>(const []);

  static String? _claveCargada;
  static Future<void>? _cargando;

  static String _clave() => 'favoritos_mascotas_${Session.idUsuario ?? "anon"}';

  static bool esFavorito(String id) => ids.value.contains(id);

  static Future<void> asegurar() {
    final clave = _clave();
    if (_claveCargada == clave) return Future.value();
    return _cargando ??= _leer(clave).whenComplete(() {
      _cargando = null;
    });
  }

  static Future<void> _leer(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    final guardados = prefs.getStringList(clave) ?? const <String>[];
    final claveOrden = '${clave}_reciente';
    final yaOrdenado = prefs.getBool(claveOrden) ?? false;
    final ordenados = List<String>.from(yaOrdenado ? guardados : guardados.reversed);
    ids.value = ordenados;
    _claveCargada = clave;
    if (!yaOrdenado) {
      await prefs.setStringList(clave, ordenados);
      await prefs.setBool(claveOrden, true);
    }
  }

  /// Devuelve true si la mascota quedó marcada como favorita.
  static Future<bool> alternar(String id) async {
    await asegurar();
    final actual = List<String>.from(ids.value);
    final yaEra = actual.contains(id);
    actual.remove(id);
    if (!yaEra) actual.insert(0, id);
    ids.value = List<String>.unmodifiable(actual);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_clave(), actual);
    return !yaEra;
  }
}
