import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/widgets/feature_icon.dart';

/// Elección entre Hombre y Mujer, con el mismo estilo de los campos de registro.
class SelectorGenero extends StatelessWidget {
  final String? valor;
  final String? error;
  final ValueChanged<String>? onChanged;

  const SelectorGenero({
    super.key,
    required this.valor,
    required this.onChanged,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Género',
            style: texto.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.texto,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(child: _opcion('Hombre')),
            const SizedBox(width: 10),
            Expanded(child: _opcion('Mujer')),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              error!,
              style: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _opcion(String opcion) {
    final elegida = valor == opcion;
    final activa = onChanged != null;
    return Material(
      color: elegida ? AppColors.rosa : const Color(0xFFFCF9FA),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: activa ? () => onChanged!(opcion) : null,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: error != null && !elegida
                  ? const Color(0xFFE53935)
                  : (elegida ? AppColors.rosa : const Color(0xFFF2BED6)),
              width: elegida ? 1.5 : 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FeatureIcon.persona(
                tamano: 20,
                color: elegida ? AppColors.blanco : AppColors.rosa,
              ),
              const SizedBox(width: 8),
              Text(
                opcion,
                style: TextStyle(
                  color: elegida ? AppColors.blanco : AppColors.texto,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
