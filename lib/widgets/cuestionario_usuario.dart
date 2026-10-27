import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/rasgos.dart';
import 'package:paw_match/widgets/logo_paw.dart';

/// Encabezado del cuestionario de personalidad del adoptante.
class EncabezadoCuestionarioUsuario extends StatelessWidget {
  final String titulo;
  final String detalle;
  final Widget? icono;
  final bool mostrarLogo;
  final TextStyle? estiloTitulo;

  const EncabezadoCuestionarioUsuario({
    super.key,
    this.titulo = 'Cuéntanos cómo eres',
    this.detalle =
        'Responde de 1 a 5. Con esto buscamos la mascota que mejor '
        'encaja contigo.',
    this.icono,
    this.mostrarLogo = true,
    this.estiloTitulo,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.bordeRosa),
      ),
      child: Column(
        children: [
          if (mostrarLogo) ...[
            const LogoPaw(tamano: 72),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icono != null) ...[
                icono!,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: estiloTitulo ??
                      t.headlineSmall?.copyWith(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// Una pregunta del cuestionario, con la misma escala del 1 al 5.
class TarjetaRasgoUsuario extends StatelessWidget {
  final Rasgo rasgo;
  final double valor;
  final ValueChanged<double>? onChanged;

  const TarjetaRasgoUsuario({
    super.key,
    required this.rasgo,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final elegido = valor.round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.rosaSuave,
        border: Border.all(color: AppColors.bordeRosa),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(rasgo.icono, size: 18, color: AppColors.rosa),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rasgo.titulo,
                  style: t.titleSmall?.copyWith(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$elegido',
                style: t.titleMedium?.copyWith(
                  color: AppColors.rosa,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(rasgo.preguntaUsuario, style: t.bodyMedium),
          Slider(
            value: valor,
            min: 1,
            max: 5,
            divisions: 4,
            label: '$elegido',
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '1 · ${rasgo.minimoUsuario}',
                  style: t.bodySmall?.copyWith(color: Colors.black54),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '5 · ${rasgo.maximoUsuario}',
                  textAlign: TextAlign.right,
                  style: t.bodySmall?.copyWith(color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
