import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Tarjeta informativa de una forma de ayudar a la Fundación.
class TarjetaAyuda extends StatelessWidget {
  final IconData icono;
  final String titulo, texto;
  const TarjetaAyuda({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.rosaClaro,
            child: Icon(icono, color: AppColors.rosa, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            titulo.toUpperCase(),
            style: t.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.texto,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 34,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.rosa,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            texto,
            style: t.bodyMedium?.copyWith(height: 1.5, color: AppColors.texto),
          ),
        ],
      ),
    );
  }
}
