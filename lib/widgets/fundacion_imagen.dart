import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/widgets/pet_card.dart' show urlFoto;

/// Imagen de la Fundación: acepta una ruta de assets (assets/...) o una
/// imagen subida al servidor (/uploads/fundacion/...). Si está vacía o falla,
/// muestra un ícono de respaldo.
class FundacionImagen extends StatelessWidget {
  final String ruta;
  final BoxFit fit;
  final IconData icono;
  final double tamanoIcono;
  final Color? fondo;

  const FundacionImagen({
    super.key,
    required this.ruta,
    this.fit = BoxFit.cover,
    this.icono = Icons.volunteer_activism,
    this.tamanoIcono = 64,
    this.fondo,
  });

  @override
  Widget build(BuildContext context) {
    final respaldo = ColoredBox(
      color: fondo ?? AppColors.rosaClaro,
      child: Center(
        child: Icon(icono, size: tamanoIcono, color: AppColors.rosa),
      ),
    );
    final r = ruta.trim();
    if (r.isEmpty || r == 'assets/fundacion/bebe.jpg') return respaldo;
    if (r.startsWith('assets/')) {
      return Image.asset(
        r,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => respaldo,
      );
    }
    return Image.network(
      urlFoto(r),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => respaldo,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
