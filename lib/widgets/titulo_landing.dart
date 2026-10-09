import 'package:flutter/material.dart';

/// Título de dos líneas en mayúsculas con una segunda línea de acento.
class TituloLanding extends StatelessWidget {
  final String texto, acento;
  final Color color;
  final Color? colorAcento;
  final double tamano;
  final TextAlign alineacion;
  final bool subrayado;
  const TituloLanding({
    super.key,
    required this.texto,
    required this.acento,
    required this.color,
    this.colorAcento,
    this.tamano = 32,
    this.alineacion = TextAlign.start,
    this.subrayado = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: color,
      fontSize: tamano,
      height: 1.12,
      fontWeight: FontWeight.w800,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${texto.toUpperCase()}\n', style: base),
          TextSpan(
            text: acento.toUpperCase(),
            style: base?.copyWith(
              color: colorAcento ?? color,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
      textAlign: alineacion,
    );
  }
}
