import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Barra de 1 a 5 para mostrar un rasgo de personalidad (solo lectura).
class RasgoBarra extends StatelessWidget {
  final IconData icono;
  final String titulo, minimo, maximo;
  final int valor;
  const RasgoBarra({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.minimo,
    required this.maximo,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: AppColors.rosa),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: t.titleSmall?.copyWith(color: AppColors.texto),
                ),
              ),
              Text(
                '$valor/5',
                style: t.labelLarge?.copyWith(color: AppColors.rosa),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: valor / 5,
              minHeight: 8,
              color: AppColors.rosa,
              backgroundColor: AppColors.bordeRosa,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  minimo,
                  style: t.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  maximo,
                  style: t.bodySmall,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
