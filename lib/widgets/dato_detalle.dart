import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Un dato de la mascota (edad, sexo, tamaño...) con ícono, etiqueta y valor.
class DatoDetalle extends StatelessWidget {
  final IconData icono;
  final String etiqueta, valor;
  const DatoDetalle({super.key, required this.icono, required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.rosaSuave, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icono, size: 22, color: AppColors.rosa),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiqueta, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(valor,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.texto),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}
