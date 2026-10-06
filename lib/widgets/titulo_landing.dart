import 'package:flutter/material.dart';

/// Título de dos líneas: la primera en negrita y la segunda en cursiva subrayada.
class TituloLanding extends StatelessWidget {
  final String texto, acento;
  final Color color;
  final double tamano;
  final TextAlign alineacion;
  const TituloLanding({
    super.key,
    required this.texto,
    required this.acento,
    required this.color,
    this.tamano = 32,
    this.alineacion = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context)
        .textTheme
        .headlineMedium
        ?.copyWith(color: color, fontSize: tamano, height: 1.12, fontWeight: FontWeight.w800);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '$texto\n', style: base),
        TextSpan(
          text: acento,
          style: base?.copyWith(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.underline,
            decorationColor: color,
          ),
        ),
      ]),
      textAlign: alineacion,
    );
  }
}
