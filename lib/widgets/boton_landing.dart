import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Botón de la landing. `sobreRosa`: va sobre fondo rosado (blanco) o sobre blanco (rosado).
/// `relleno`: relleno sólido o solo contorno.
class BotonLanding extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;
  final bool sobreRosa, relleno, expandido;
  const BotonLanding({
    super.key,
    required this.texto,
    required this.onPressed,
    this.sobreRosa = false,
    this.relleno = true,
    this.expandido = false,
  });

  @override
  Widget build(BuildContext context) {
    final tamano = expandido ? const Size.fromHeight(50) : const Size(170, 50);
    final etiqueta = Text(texto, style: const TextStyle(fontWeight: FontWeight.w700));
    final forma = const StadiumBorder();

    if (relleno) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: sobreRosa ? Colors.white : AppColors.rosa,
          foregroundColor: sobreRosa ? AppColors.rosa : Colors.white,
          minimumSize: tamano,
          shape: forma,
        ),
        child: etiqueta,
      );
    }
    final color = sobreRosa ? Colors.white : AppColors.rosa;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        minimumSize: tamano,
        shape: forma,
      ),
      child: etiqueta,
    );
  }
}
