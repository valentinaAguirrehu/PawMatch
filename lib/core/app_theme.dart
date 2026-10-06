import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Estilos de componentes en UN solo lugar. Las pantallas usan Theme.of(context)
/// o AppColors; no definen colores propios.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.rosa).copyWith(
      primary: AppColors.rosa,
      onPrimary: AppColors.blanco,
      primaryContainer: AppColors.rosaClaro,
      onPrimaryContainer: AppColors.texto,
      secondary: AppColors.rosa,
      onSecondary: AppColors.blanco,
      secondaryContainer: AppColors.rosaClaro,
      onSecondaryContainer: AppColors.texto,
      surface: AppColors.blanco,
      onSurface: AppColors.texto,
      surfaceContainerLow: AppColors.rosaSuave,
      surfaceContainerHighest: AppColors.rosaClaro,
      outline: AppColors.bordeRosa,
      outlineVariant: AppColors.bordeRosa,
      surfaceTint: Colors.transparent,
    );

    OutlineInputBorder borde(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.blanco,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.blanco,
        foregroundColor: AppColors.texto,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.rosa),
      ),
      cardTheme: CardThemeData(
        color: AppColors.rosaSuave,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.rosaSuave,
        border: borde(AppColors.bordeRosa),
        enabledBorder: borde(AppColors.bordeRosa),
        focusedBorder: borde(AppColors.rosa, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.rosa,
          foregroundColor: AppColors.blanco,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.rosa,
          side: const BorderSide(color: AppColors.rosa, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.rosa),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.rosaSuave,
        selectedColor: AppColors.rosaClaro,
        checkmarkColor: AppColors.rosa,
        side: const BorderSide(color: AppColors.bordeRosa),
        labelStyle: const TextStyle(color: AppColors.texto),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.blanco : AppColors.bordeRosa),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.rosa : AppColors.rosaSuave),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.rosa,
        thumbColor: AppColors.rosa,
        inactiveTrackColor: AppColors.bordeRosa,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.rosa),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.rosa,
        foregroundColor: AppColors.blanco,
      ),
    );
  }
}
