import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

class NavItem {
  final Widget icono;
  final Widget? iconoActivo;
  final String etiqueta;
  final bool esDestacado;

  const NavItem({
    required this.icono,
    this.iconoActivo,
    required this.etiqueta,
    this.esDestacado = false,
  });
}

/// Barra inferior flotante blanca, mediana y centrada con botón circular destacado al centro.
class NavFlotante extends StatelessWidget {
  final List<NavItem> items;
  final int indice;
  final ValueChanged<int> onTap;

  const NavFlotante({
    super.key,
    required this.items,
    required this.indice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: SizedBox(
        height: 64,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppColors.rosa.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < items.length; i++)
                  _buildBoton(context, i),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoton(BuildContext context, int i) {
    final item = items[i];
    final activo = i == indice;

    if (item.esDestacado) {
      return Tooltip(
        message: item.etiqueta,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(i),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 220),
            scale: activo ? 1.08 : 1.0,
            curve: Curves.easeOutBack,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.rosa,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.rosa.withValues(alpha: activo ? 0.45 : 0.30),
                    blurRadius: activo ? 14 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: IconTheme(
                  data: const IconThemeData(
                    color: Colors.white,
                    size: 26,
                  ),
                  child: (activo && item.iconoActivo != null)
                      ? item.iconoActivo!
                      : item.icono,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: item.etiqueta,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activo
                ? AppColors.rosa.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: IconTheme(
            data: IconThemeData(
              color: activo ? AppColors.rosa : const Color(0xFF9E9E9E),
              size: 24,
            ),
            child: (activo && item.iconoActivo != null)
                ? item.iconoActivo!
                : item.icono,
          ),
        ),
      ),
    );
  }
}
