import 'package:flutter/foundation.dart';

/// Avisa a Match Perfecto que las respuestas cambiaron.
///
/// Guarda la copia recién enviada para que el ranking no dependa de una
/// lectura anterior (ni de la caché del navegador) y pueda reordenarse
/// con esos valores en el siguiente cálculo.
class MatchEstado extends ChangeNotifier {
  MatchEstado._();

  static final MatchEstado instancia = MatchEstado._();

  Map<String, int>? _respuestas;

  /// Copia de la última vez que se guardó el cuestionario en esta sesión.
  /// Varios cálculos pueden leerla: no se descarta hasta cerrar sesión.
  Map<String, int>? get respuestas {
    final actuales = _respuestas;
    if (actuales == null) return null;
    return Map<String, int>.from(actuales);
  }

  void publicar(Map<String, int> respuestas) {
    _respuestas = Map<String, int>.from(respuestas);
    notifyListeners();
  }

  void reiniciar() {
    _respuestas = null;
  }
}
