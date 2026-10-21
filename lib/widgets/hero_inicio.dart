import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/logo_paw.dart';

/// Encabezado del inicio: foto, saludo y botón de salir.
class HeroInicio extends StatelessWidget {
  final String nombre;
  final VoidCallback onCerrarSesion;
  final VoidCallback? onVerMascotas;
  final VoidCallback? onAdopciones;
  final VoidCallback? onApadrinamientos;

  const HeroInicio({
    super.key,
    required this.nombre,
    required this.onCerrarSesion,
    this.onVerMascotas,
    this.onAdopciones,
    this.onApadrinamientos,
  });

  @override
  Widget build(BuildContext context) {
    final alto = (MediaQuery.of(context).size.height * 0.58)
        .clamp(420.0, 500.0)
        .toDouble();

    return SizedBox(
      height: alto,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onVerMascotas,
              child: Image.asset(
                'assets/images/inicio/abrazo.jpg',
                fit: BoxFit.cover,
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.28, 0.55, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BarraSuperior(
                      nombre: nombre,
                      onCerrarSesion: onCerrarSesion,
                    ),
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, (1 - v) * 24),
                          child: child,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Un hogar para cada huella, un futuro para cada vida.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Descubre el poder de transformar historias. A través de la adopción y el apadrinamiento, le das una segunda oportunidad a un animal que solo busca amar y ser amado.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraSuperior extends StatelessWidget {
  final String nombre;
  final VoidCallback onCerrarSesion;

  const _BarraSuperior({
    required this.nombre,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const LogoPaw(tamano: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'Hola, $nombre',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Cerrar sesión',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            foregroundColor: AppColors.rosa,
          ),
          onPressed: onCerrarSesion,
          icon: const FeatureIcon.cerrarSesion(color: AppColors.rosa),
        ),
      ],
    );
  }
}
