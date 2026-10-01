import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

class LogoPaw extends StatelessWidget {
  final double tamano;
  const LogoPaw({super.key, this.tamano = 92});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: tamano,
    height: tamano,
    child: ClipOval(
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.pets, size: tamano * 0.5, color: AppColors.rosa),
      ),
    ),
  );
}
