import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Fila fija con línea vertical (sección de apadrinamiento).
class FilaPunto extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final bool ultimo;

  const FilaPunto({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
    this.ultimo = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.rosa,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: Colors.white, size: 22),
              ),
              if (!ultimo)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.bordeRosa,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: ultimo ? 0 : 18, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.texto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    texto,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.texto.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
