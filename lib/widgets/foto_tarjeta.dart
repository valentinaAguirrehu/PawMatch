import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/widgets/feature_icon.dart';

/// Foto redondeada. Con [pie] muestra un botón sobre la imagen.
class FotoTarjeta extends StatelessWidget {
  final String asset;
  final double alto;
  final String? pie;
  final VoidCallback? onTap;

  const FotoTarjeta({
    super.key,
    required this.asset,
    required this.alto,
    this.pie,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Material(
          color: AppColors.rosaSuave,
          child: InkWell(
            onTap: pie == null ? null : onTap,
            child: Stack(
              children: [
                Image.asset(
                  asset,
                  height: alto,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                if (pie != null) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const FeatureIcon.mascota(
                            tamano: 16,
                            color: AppColors.rosa,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pie!,
                              style: const TextStyle(
                                color: AppColors.rosa,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: AppColors.rosa,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
