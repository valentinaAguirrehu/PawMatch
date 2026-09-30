import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';

/// Tarjeta morada con bordes redondeados: presenta la Fundación y abre misión / visión.
class FundacionBanner extends StatelessWidget {
  final VoidCallback onMision, onVision;
  const FundacionBanner({
    super.key,
    required this.onMision,
    required this.onVision,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppColors.rosa,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FundacionInfo.nombre,
                  style: t.labelLarge?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  FundacionInfo.resumen,
                  style: t.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: onMision,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.rosa,
                        minimumSize: const Size(0, 44),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Misión'),
                    ),
                    OutlinedButton(
                      onPressed: onVision,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        minimumSize: const Size(0, 44),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Visión'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.pets,
            size: 76,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
