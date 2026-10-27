import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Título, párrafo y el contenido de una sección del inicio.
/// Con [fondo] pinta el bloque; [curvaSuperior] redondea solo el borde de arriba.
class SeccionInicio extends StatelessWidget {
  final String titulo;
  final String texto;
  final List<Widget> hijos;
  final Color? fondo;
  final bool curvaSuperior;

  const SeccionInicio({
    super.key,
    required this.titulo,
    required this.texto,
    required this.hijos,
    this.fondo,
    this.curvaSuperior = false,
  });

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: AppColors.texto,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            texto,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.texto.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 20),
          ...hijos,
        ],
      ),
    );

    if (fondo == null && !curvaSuperior) return contenido;

    return Container(
      margin: EdgeInsets.only(top: curvaSuperior ? 8 : 0),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: curvaSuperior
            ? const BorderRadius.vertical(top: Radius.circular(40))
            : null,
      ),
      child: contenido,
    );
  }
}
