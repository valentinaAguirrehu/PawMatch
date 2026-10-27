import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/seguimiento_apadrinamiento.dart';
import 'package:paw_match/widgets/star_rating_selector.dart';

/// Tarjeta para visualizar un registro individual de seguimiento en el historial.
class TarjetaSeguimiento extends StatelessWidget {
  final SeguimientoApadrinamientoItem seguimiento;
  final bool mostrarBorde;

  const TarjetaSeguimiento({
    super.key,
    required this.seguimiento,
    this.mostrarBorde = true,
  });

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cumplio = seguimiento.cumplimiento;
    final esAlerta = !cumplio || seguimiento.calificacion <= 2;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: mostrarBorde
            ? Border.all(
                color: esAlerta ? Colors.red.shade200 : const Color(0xFFF0E5EC),
                width: esAlerta ? 1.4 : 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Fecha, Estrellas y Badge de Cumplimiento
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _formatearFecha(seguimiento.fechaSeguimiento),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              // Badge cumplió / no cumplió
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cumplio ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cumplio ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cumplio ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 14,
                      color: cumplio ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cumplio ? 'Cumplió' : 'Incumplió',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: cumplio ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Calificación en estrellas y Administrador
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StarRatingSelector(
                rating: seguimiento.calificacion,
                readOnly: true,
                starSize: 18,
              ),
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 14, color: AppColors.rosa),
                  const SizedBox(width: 4),
                  Text(
                    seguimiento.adminNombre,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.rosa,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Observaciones
          if (seguimiento.observaciones.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                seguimiento.observaciones.trim(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.35,
                ),
              ),
            ),
          ],

          // Próximo seguimiento si está programado
          if (seguimiento.proximoSeguimiento != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.alarm,
                  size: 14,
                  color: Colors.purple.shade400,
                ),
                const SizedBox(width: 5),
                Text(
                  'Próximo seguimiento programado: ${_formatearFecha(seguimiento.proximoSeguimiento!)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
