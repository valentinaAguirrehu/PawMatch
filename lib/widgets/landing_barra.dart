import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/layout.dart';
import 'package:paw_match/widgets/logo_paw.dart';

/// Barra superior de la landing: sello de la fundación a la izquierda,
/// botones centrados y logo de Paw Match a la derecha.
class LandingBarra extends StatelessWidget {
  final VoidCallback onIniciarSesion, onRegistrarse;
  final List<EnlaceBarra> enlaces;

  const LandingBarra({
    super.key,
    required this.onIniciarSesion,
    required this.onRegistrarse,
    this.enlaces = const [],
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width < 60 || size.height < 60) return const SizedBox.shrink();
    final ancho = size.width;
    final muyAngosto = ancho < 360;
    final angosto = ancho < 520;
    final tamLogo = muyAngosto ? 40.0 : (angosto ? 46.0 : 52.0);
    return Material(
      color: const Color(0xFFFFA3C8),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: muyAngosto ? 10 : (angosto ? 14 : 24),
            vertical: 8,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Layout.anchoMaximo),
              child: SizedBox(
                height: muyAngosto ? 44 : (angosto ? 48 : 52),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _botonIniciar(muyAngosto, angosto),
                        SizedBox(width: muyAngosto ? 6 : (angosto ? 8 : 10)),
                        _botonRegistro(muyAngosto, angosto),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _Logo(tamano: tamLogo),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ancho >= Layout.escritorio)
                            for (final enlace in enlaces)
                              TextButton(
                                onPressed: enlace.onPressed,
                                child: Text(enlace.texto),
                              ),
                          LogoPaw(tamano: tamLogo),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonIniciar(bool muyAngosto, bool angosto) {
    return OutlinedButton(
      onPressed: onIniciarSesion,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        side: const BorderSide(color: Colors.white, width: 1.4),
        shape: const StadiumBorder(),
        minimumSize: Size(0, angosto ? 36 : 40),
        padding: EdgeInsets.symmetric(
          horizontal: muyAngosto ? 10 : (angosto ? 14 : 18),
        ),
        visualDensity: VisualDensity.compact,
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: muyAngosto ? 12 : (angosto ? 13 : 14.5),
        ),
      ),
      child: const Text('Iniciar sesión'),
    );
  }

  Widget _botonRegistro(bool muyAngosto, bool angosto) {
    return FilledButton(
      onPressed: onRegistrarse,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.rosa,
        elevation: 0,
        shape: const StadiumBorder(),
        minimumSize: Size(0, angosto ? 36 : 40),
        padding: EdgeInsets.symmetric(
          horizontal: muyAngosto ? 10 : (angosto ? 14 : 20),
        ),
        visualDensity: VisualDensity.compact,
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: muyAngosto ? 12 : (angosto ? 13 : 14.5),
        ),
      ),
      child: const Text('Registrarse'),
    );
  }
}

class EnlaceBarra {
  final String texto;
  final VoidCallback onPressed;

  const EnlaceBarra(this.texto, this.onPressed);
}

/// Sello de la Fundación Maritza Arévalo.
class _Logo extends StatelessWidget {
  final double tamano;
  const _Logo({required this.tamano});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: ClipOval(
        child: Image.asset(
          'assets/images/Logo Fundación.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
