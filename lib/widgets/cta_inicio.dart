import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/widgets/feature_icon.dart';

/// Cierre del inicio: invita a ver mascotas o a hacer el match.
class CtaInicio extends StatelessWidget {
  final VoidCallback onVerMascotas;
  final VoidCallback onVerMatch;

  const CtaInicio({
    super.key,
    required this.onVerMascotas,
    required this.onVerMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.bordeRosa, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.rosa.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.rosaSuave,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                FeatureIcon.huella,
                style: TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '¿Listo para cambiar una vida hoy?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                height: 1.2,
                fontWeight: FontWeight.w900,
                color: AppColors.texto,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ya sea adoptando, apadrinando o compartiendo nuestra misión, tu apoyo marca la diferencia entre el olvido y una vida llena de amor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.texto.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosa,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: onVerMascotas,
              icon: const FeatureIcon.mascota(tamano: 18, color: Colors.white),
              label: const Text('Deseo conocer a los peluditos'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rosa,
                side: const BorderSide(color: AppColors.rosa, width: 1.5),
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: onVerMatch,
              icon: const FeatureIcon.favorito(
                tamano: 18,
                color: AppColors.rosa,
              ),
              label: const Text('Deseo conocer a mi alma gemela'),
            ),
          ],
        ),
      ),
    );
  }
}
