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
          // Fila superior: Consecutivo, Ciclo, Fecha y Badge de Cumplimiento
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.rosa.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${seguimiento.numeroSeguimiento} · Ciclo ${seguimiento.ciclo}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: AppColors.rosa,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatearFecha(seguimiento.fechaSeguimiento),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              // Badge cumplió / no cumplió
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
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
                      size: 13,
                      color: cumplio ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cumplio ? 'Cumplió' : 'Incumplió',
                      style: TextStyle(
                        fontSize: 11,
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

          // Aportes del padrino revisados en este seguimiento
          if (seguimiento.aportes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8ECF4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aportes revisados:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...seguimiento.aportes.map((ap) {
                    final rec = ap.recibido;
                    final colorFondo = rec ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
                    final colorBorde = rec ? Colors.green.shade300 : Colors.red.shade400;
                    final colorTexto = rec ? Colors.green.shade900 : Colors.red.shade900;
                    final colorIcono = rec ? Colors.green.shade700 : Colors.red.shade700;

                    String detalle = '';
                    if (ap.tipo == 'monetario') {
                      detalle = 'Monetario: ${rec ? "Recibido" : "NO RECIBIDO"}';
                      if (rec && ap.montoRecibido != null) {
                        detalle += ' · \$${ap.montoRecibido!.toStringAsFixed(0)}';
                      }
                      if (rec && ap.medio != null) {
                        detalle += ' (${ap.medio})';
                      }
                      if (rec && ap.referencia != null && ap.referencia!.isNotEmpty) {
                        detalle += ' Ref: ${ap.referencia}';
                      }
                    } else if (ap.tipo == 'especie') {
                      detalle = 'Especie: ${rec ? "Recibido" : "NO RECIBIDO"}';
                      if (rec && ap.detalleRecibido != null && ap.detalleRecibido!.isNotEmpty) {
                        detalle += ' (${ap.detalleRecibido})';
                      }
                    } else {
                      detalle = 'Otra ayuda: ${rec ? "Cumplió" : "NO CUMPLIÓ"}';
                      if (rec && ap.detalleRecibido != null && ap.detalleRecibido!.isNotEmpty) {
                        detalle += ' (${ap.detalleRecibido})';
                      }
                    }

                    if (!rec && ap.observacion != null && ap.observacion!.trim().isNotEmpty) {
                      detalle += ' · Motivo: ${ap.observacion!.trim()}';
                    }

                    return Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorFondo,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorBorde),
                      ),
                      child: Row(
                        children: [
                          Icon(rec ? Icons.check_circle_outline : Icons.cancel_outlined, size: 14, color: colorIcono),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              detalle,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: colorTexto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Observaciones
          if (seguimiento.observaciones.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
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
                  fontSize: 12.5,
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
