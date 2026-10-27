import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Selector interactivo o visualizador de calificación con 5 estrellas.
class StarRatingSelector extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onRatingChanged;
  final double starSize;
  final Color activeColor;
  final Color inactiveColor;
  final bool readOnly;
  final bool mostrarEtiqueta;

  const StarRatingSelector({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.starSize = 32,
    this.activeColor = const Color(0xFFFFB300), // Dorado vibrante
    this.inactiveColor = const Color(0xFFE0E0E0),
    this.readOnly = false,
    this.mostrarEtiqueta = false,
  });

  static const _etiquetas = [
    'Selecciona una calificación',
    '1 - Muy deficiente (Incumplimiento)',
    '2 - Deficiente (Incumplimiento)',
    '3 - Aceptable',
    '4 - Muy bueno',
    '5 - Excelente cumplimiento',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starNumber = index + 1;
            final isFilled = starNumber <= rating;

            final starIcon = Icon(
              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isFilled ? activeColor : inactiveColor,
              size: starSize,
            );

            if (readOnly || onRatingChanged == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: starIcon,
              );
            }

            return InkWell(
              onTap: () => onRatingChanged!(starNumber),
              borderRadius: BorderRadius.circular(starSize),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: AnimatedScale(
                  scale: isFilled ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: starIcon,
                ),
              ),
            );
          }),
        ),
        if (mostrarEtiqueta) ...[
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              rating >= 1 && rating <= 5 ? _etiquetas[rating] : _etiquetas[0],
              key: ValueKey<int>(rating),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: rating <= 2 && rating > 0
                    ? Colors.red.shade600
                    : (rating >= 4 ? Colors.green.shade700 : AppColors.texto),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Badge compacto de estrellas para listas y cabeceras (ej. ★ 4.5).
class StarRatingBadge extends StatelessWidget {
  final double rating;
  final int totalSeguimientos;
  final bool compacto;
  final Color colorFondo;

  const StarRatingBadge({
    super.key,
    required this.rating,
    this.totalSeguimientos = 0,
    this.compacto = false,
    this.colorFondo = const Color(0xFFFFF3E0),
  });

  @override
  Widget build(BuildContext context) {
    final ratingFormateado = rating > 0 ? rating.toStringAsFixed(1) : 'Nuevo';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 8 : 10,
        vertical: compacto ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 16,
            color: Color(0xFFFF9800),
          ),
          const SizedBox(width: 4),
          Text(
            ratingFormateado,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: Color(0xFFE65100),
            ),
          ),
          if (!compacto && totalSeguimientos > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($totalSeguimientos)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
