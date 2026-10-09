import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Foto de assets con esquinas redondeadas; si falla, muestra una huella.
class ImagenFundacion extends StatelessWidget {
  final String ruta;
  final double? alto, ancho, radio;
  const ImagenFundacion({super.key, required this.ruta, this.alto, this.ancho, this.radio = 24});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radio ?? 0),
        child: SizedBox(
          height: alto,
          width: ancho ?? double.infinity,
          child: Image.asset(
            ruta,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: AppColors.rosaClaro,
              child: Center(child: Icon(Icons.pets, color: AppColors.rosa, size: 40)),
            ),
          ),
        ),
      );
}
