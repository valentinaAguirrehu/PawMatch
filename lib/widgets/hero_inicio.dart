import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/services/adoption_service.dart';
import 'package:paw_match/services/apadrinamiento_service.dart';
import 'package:paw_match/widgets/feature_icon.dart';
import 'package:paw_match/widgets/logo_paw.dart';

/// Encabezado del inicio: foto, saludo y accesos a adopciones y apadrinamientos.
class HeroInicio extends StatelessWidget {
  final String nombre;
  final VoidCallback onCerrarSesion;
  final VoidCallback onVerMascotas;
  final VoidCallback onAdopciones;
  final VoidCallback onApadrinamientos;

  const HeroInicio({
    super.key,
    required this.nombre,
    required this.onCerrarSesion,
    required this.onVerMascotas,
    required this.onAdopciones,
    required this.onApadrinamientos,
  });

  @override
  Widget build(BuildContext context) {
    final alto = (MediaQuery.of(context).size.height * 0.80)
        .clamp(560.0, 680.0)
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
                          const SizedBox(height: 20),
                          _AvisoBoton(
                            avisos: AdoptionService.noLeidasUsuario,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.rosa,
                                minimumSize: const Size.fromHeight(52),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              onPressed: onAdopciones,
                              icon: const FeatureIcon.mascota(
                                tamano: 18,
                                color: AppColors.rosa,
                              ),
                              label: const Text('Ver mis Adopciones'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _AvisoBoton(
                            avisos: ApadrinamientoService.noLeidasUsuario,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.14,
                                ),
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                minimumSize: const Size.fromHeight(52),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              onPressed: onApadrinamientos,
                              icon: const FeatureIcon.apadrinar(
                                tamano: 18,
                                color: Colors.white,
                              ),
                              label: const Text('Ver mis apadrinaciones'),
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

  const _BarraSuperior({required this.nombre, required this.onCerrarSesion});

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
        const SizedBox(width: 10),
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

class _AvisoBoton extends StatelessWidget {
  final ValueNotifier<int> avisos;
  final Widget child;

  const _AvisoBoton({required this.avisos, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: avisos,
      builder: (context, count, _) => Badge(
        isLabelVisible: count > 0,
        alignment: const Alignment(0.86, -0.9),
        label: Text(count > 1 ? '$count' : 'Nuevo'),
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
        child: child,
      ),
    );
  }
}
