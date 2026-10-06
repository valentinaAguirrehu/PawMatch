import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Tarjeta de un logro: ícono, número grande y descripción.
class StatLogro extends StatelessWidget {
  final IconData icono;
  final String valor, etiqueta;
  const StatLogro({super.key, required this.icono, required this.valor, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.rosaClaro, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icono, color: AppColors.rosa, size: 28),
        const SizedBox(height: 10),
        Text(valor, style: t.headlineMedium?.copyWith(color: AppColors.rosa, fontWeight: FontWeight.w800)),
        Text(etiqueta, style: t.bodyMedium?.copyWith(color: AppColors.texto)),
      ]),
    );
  }
}
