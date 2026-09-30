import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Píldora seleccionable (Adopción / Apadrinamiento).
class ChipSeleccion extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;
  const ChipSeleccion({
    super.key,
    required this.texto,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = seleccionado ? Colors.white : AppColors.texto;
    return Material(
      color: seleccionado ? AppColors.rosa : AppColors.rosaSuave,
      shape: StadiumBorder(
        side: BorderSide(
          color: seleccionado ? AppColors.rosa : AppColors.bordeRosa,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                texto,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
