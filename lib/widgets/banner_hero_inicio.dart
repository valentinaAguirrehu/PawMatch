import 'package:flutter/material.dart';

/// Clipper con corte diagonal en la parte inferior, idéntico a la referencia visual.
class DiagonalBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height - 38);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Banner hero inspirado en la referencia "Fundación Tepa", adaptado a "Fundación Maritza Arévalo".
/// Utiliza fundacion_hero.jpg como imagen de fondo, título destacado y los dos botones de acción.
class BannerHeroInicio extends StatelessWidget {
  const BannerHeroInicio({super.key});

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final alto = (MediaQuery.of(context).size.height * 0.55)
        .clamp(400.0, 520.0)
        .toDouble();

    return ClipPath(
      clipper: DiagonalBottomClipper(),
      child: Container(
        height: alto,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF1F2421),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Foto de fondo (fundacion_hero.jpg)
            Image.asset(
              'assets/images/inicio/fundacion_hero.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFF2E342A)),
            ),

            // 2. Degradado suave y ligero para mantener la foto clara y vívida
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.50, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.46),
                  ],
                ),
              ),
            ),

            // 3. Contenido textual con estilo idéntico a la referencia
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 38),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtítulo pequeño en mayúsculas
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'EL ARTE DE RESCATAR PELUDITOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Título principal
                  const Text(
                    'Fundación Maritza Arévalo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Descripción institucional
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ancho > 600 ? 560 : double.infinity),
                    child: Text(
                      'Buscamos proteger la vida de perros y gatos en estado de maltrato y abandono en San Juan de Pasto. Les brindamos alimentos, medicamentos y albergue, con el fin de mejorar su calidad de vida y conseguirles un hogar.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.94),
                        fontSize: 13.5,
                        height: 1.45,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
