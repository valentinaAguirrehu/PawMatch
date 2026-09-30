import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Chip pastel con un dato corto de la mascota (edad, sexo, vacunas...).
class DatoChip extends StatelessWidget {
  final String texto;
  final Color color;
  const DatoChip({super.key, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      texto,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: AppColors.texto),
    ),
  );
}
