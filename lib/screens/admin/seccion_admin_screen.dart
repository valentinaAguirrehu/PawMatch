import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Pantalla provisional para las secciones de administración que todavía no
/// se han construido. Cuando implementes cada una, reemplaza la que
/// corresponda en `_paginaGestion()` de menu_screen.dart por la pantalla real.
class SeccionAdminScreen extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String detalle;

  const SeccionAdminScreen({
    super.key,
    required this.titulo,
    required this.icono,
    required this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.rosaClaro,
              child: Icon(icono, size: 40, color: AppColors.rosa),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(detalle, textAlign: TextAlign.center, style: t.bodyLarge),
            const SizedBox(height: 16),
            Text(
              'Estará disponible pronto',
              style: t.labelLarge?.copyWith(color: AppColors.rosa),
            ),
          ],
        ),
      ),
    );
  }
}
