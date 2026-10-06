import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Botón blanco con texto rosado (sobre fondo rosado). Muestra un cargando.
class BotonBlanco extends StatelessWidget {
  final String texto;
  final bool cargando;
  final VoidCallback? onPressed;
  const BotonBlanco({super.key, required this.texto, required this.onPressed, this.cargando = false});

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: cargando ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.rosa,
          disabledBackgroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        child: cargando
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.rosa),
              )
            : Text(texto),
      );
}
