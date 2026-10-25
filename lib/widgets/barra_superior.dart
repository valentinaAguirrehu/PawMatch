import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/widgets/feature_icon.dart';

/// Barra de mascotas y perfil. Mismos tamaños, posición y sombras.
class BarraSuperior extends StatelessWidget {
  final IconData iconoTitulo;
  final String titulo;
  final VoidCallback onCerrarSesion;

  /// Si se indica, el círculo de la izquierda vuelve atrás en lugar de mostrar la huella.
  final VoidCallback? onVolver;

  const BarraSuperior({
    super.key,
    required this.iconoTitulo,
    required this.titulo,
    required this.onCerrarSesion,
    this.onVolver,
  });

  static const _sombra = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Row(
        children: [
          Tooltip(
            message: onVolver == null ? 'Paw Match' : 'Volver',
            child: GestureDetector(
              onTap: onVolver,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.rosa.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  boxShadow: _sombra,
                ),
                child: Center(
                  child: Icon(
                    onVolver == null ? Icons.pets : Icons.arrow_back_rounded,
                    color: AppColors.rosa,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.bordeRosa),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconoTitulo, size: 16, color: AppColors.rosa),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Cerrar sesión',
            child: GestureDetector(
              onTap: onCerrarSesion,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bordeRosa),
                  boxShadow: _sombra,
                ),
                child: const Center(
                  child: FeatureIcon.cerrarSesion(
                    color: AppColors.rosa,
                    tamano: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
