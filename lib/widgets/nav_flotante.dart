import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

class NavItem {
  final IconData icono;
  final String etiqueta;
  const NavItem(this.icono, this.etiqueta);
}

/// Barra inferior flotante rosada y redondeada; la pestaña activa va en un círculo blanco.
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
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(32, 8, 32, 12),
    child: Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.rosa,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < items.length; i++)
            Tooltip(
              message: items[i].etiqueta,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == indice ? Colors.white : Colors.transparent,
                  ),
                  child: Icon(
                    items[i].icono,
                    color: i == indice ? AppColors.rosa : Colors.white70,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
