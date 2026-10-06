import 'package:flutter/material.dart';

/// Paleta única de Paw Match: SOLO rosado y blanco.
/// Los tonos claros son el mismo rosado mezclado con blanco (no son colores nuevos).
class AppColors {
  AppColors._();

  static const rosa = Color(0xFFED4F9D); // color principal
  static const blanco = Colors.white;

  // Rosado suavizado (rosa sobre blanco) para fondos, bordes y tarjetas
  static const rosaSuave = Color(0xFFFDEDF5); // ~10 %
  static const rosaClaro = Color(0xFFFBDCEB); // ~20 %
  static const bordeRosa = Color(0xFFF9C1DE); // ~35 %

  // Texto: gris casi negro, neutro, para que se lea bien sobre blanco y rosado
  static const texto = Color(0xFF2E2A2C);

  /// Fondos de tarjetas y chips (se alternan en orden).
  static const pastel = [rosaSuave, rosaClaro];
}
