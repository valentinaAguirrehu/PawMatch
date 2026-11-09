import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Botón de la landing. `sobreRosa`: va sobre fondo rosado (blanco) o sobre blanco (rosado).
/// `relleno`: relleno sólido o solo contorno.
class BotonLanding extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;
  final bool sobreRosa, relleno, expandido;
  final IconData? icono;

  const BotonLanding({
    super.key,
    required this.texto,
    required this.onPressed,
    this.sobreRosa = false,
    this.relleno = true,
    this.expandido = false,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final tamano = expandido ? const Size.fromHeight(48) : const Size(0, 46);
    final contenido = Row(
      mainAxisSize: expandido ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 18),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
    const forma = StadiumBorder();
    const pad = EdgeInsets.symmetric(horizontal: 20, vertical: 12);

    if (relleno) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: sobreRosa ? Colors.white : AppColors.rosa,
          foregroundColor: sobreRosa ? AppColors.rosa : Colors.white,
          minimumSize: tamano,
          padding: pad,
          shape: forma,
        ),
        child: contenido,
      );
    }
    final color = sobreRosa ? Colors.white : AppColors.rosa;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        minimumSize: tamano,
        padding: pad,
        shape: forma,
      ),
      child: contenido,
    );
  }
}
