import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/widgets/feature_icon.dart';

/// Confirmación antes de salir de la cuenta.
class DialogoCerrarSesion extends StatelessWidget {
  const DialogoCerrarSesion({super.key});

  static Future<bool> mostrar(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => const DialogoCerrarSesion(),
    );
    return confirmar == true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          FeatureIcon.cerrarSesion(color: AppColors.rosa),
          SizedBox(width: 10),
          Text('Cerrar sesión'),
        ],
      ),
      content: const Text(
        '¿Estás seguro de que deseas cerrar sesión?',
        style: TextStyle(fontSize: 15),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.rosa,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sí, cerrar sesión'),
        ),
      ],
    );
  }
}
