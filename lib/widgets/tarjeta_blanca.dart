import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Tarjeta blanca redondeada con un título, para pantallas de fondo rosado.
class TarjetaBlanca extends StatelessWidget {
  final String titulo;
  final IconData? icono;
  final Widget child;
  const TarjetaBlanca({super.key, required this.titulo, required this.child, this.icono});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icono != null) ...[Icon(icono, size: 20, color: AppColors.rosa), const SizedBox(width: 8)],
            Text(titulo,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.texto)),
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}
