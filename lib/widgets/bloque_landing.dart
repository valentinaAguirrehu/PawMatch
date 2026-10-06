import 'package:flutter/material.dart';

/// Bloque con esquinas muy redondeadas (rosado o blanco) para las secciones de la landing.
class BloqueLanding extends StatelessWidget {
  final Color color;
  final EdgeInsets padding;
  final Widget child;
  const BloqueLanding({super.key, required this.color, required this.padding, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(32)),
        child: child,
      );
}
