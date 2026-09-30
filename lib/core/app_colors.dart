import 'package:flutter/material.dart';

/// Paleta única de Paw Match. Si ya tienes un archivo de colores, pega estas
/// constantes ahí y borra los `const _naranja = ...` sueltos de cada pantalla.
class AppColors {
  AppColors._();

  static const naranja = Color(0xFFF97316);
  static const marron = Color(0xFF7C3A10);
  static const durazno = Color(0xFFFFF7ED);
  static const bordeDurazno = Color(0xFFFED7AA);
  static const rosaSuave = Color(0xFFFFD9CF); // fondo de la tarjeta de la foto

  /// Colores pastel para los chips de datos (se reparten en orden).
  static const pastel = [
    Color(0xFFDDF5E3), // verde
    Color(0xFFDCEBFF), // celeste
    Color(0xFFF0E2FF), // lila
    Color(0xFFFFF0BF), // amarillo
    Color(0xFFFFE1D6), // durazno
  ];
}
