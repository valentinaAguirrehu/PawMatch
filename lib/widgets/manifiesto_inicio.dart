import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Cita y texto sobre el amor hacia los animales.
class ManifiestoInicio extends StatelessWidget {
  const ManifiestoInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'El Amor Animal Transforma el Mundo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: AppColors.texto,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.rosa, Color(0xFF8E2A5A)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppColors.rosa.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Text(
              'Amar y respetar a los animales refleja la calidez y madurez de una comunidad. Defender sus derechos y procurar su bienestar nos conecta con nuestra propia humanidad. Cada pequeño gesto de empatía hacia ellos crea una cadena de bondad que nos inspira a todos a ser mejores personas.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
