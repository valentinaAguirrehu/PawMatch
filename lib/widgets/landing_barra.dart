import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/fundacion_info.dart';
import 'package:paw_match/core/layout.dart';
import 'package:paw_match/widgets/fundacion_imagen.dart';

/// Barra superior fija de la landing: logo a la izquierda y los botones
/// "Iniciar sesión" y "Registrarse" a la derecha (se compacta en celular).
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
    final ancho = MediaQuery.sizeOf(context).width;
    final angosto = ancho < 480;
    return Material(
      color: const Color(0xFFFFA3C8),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: angosto ? 12 : 24,
            vertical: 8,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Layout.anchoMaximo),
              child: Row(
                children: [
                  const _Logo(),
                  if (!angosto) ...[
                    const SizedBox(width: 10),
                    Text(
                      'Paw Match',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (ancho >= Layout.escritorio)
                    for (final enlace in enlaces)
                      TextButton(
                        onPressed: enlace.onPressed,
                        child: Text(enlace.texto),
                      ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: onIniciarSesion,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      side: const BorderSide(color: Colors.white, width: 1.4),
                      shape: const StadiumBorder(),
                      minimumSize: Size(0, angosto ? 36 : 40),
                      padding: EdgeInsets.symmetric(
                        horizontal: angosto ? 12 : 18,
                      ),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: angosto ? 13 : 14.5,
                      ),
                    ),
                    child: const Text('Iniciar sesión'),
                  ),
                  SizedBox(width: angosto ? 8 : 10),
                  FilledButton(
                    onPressed: onRegistrarse,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.rosa,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      minimumSize: Size(0, angosto ? 36 : 40),
                      padding: EdgeInsets.symmetric(
                        horizontal: angosto ? 14 : 20,
                      ),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: angosto ? 13 : 14.5,
                      ),
                    ),
                    child: const Text('Registrarse'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EnlaceBarra {
  final String texto;
  final VoidCallback onPressed;

  const EnlaceBarra(this.texto, this.onPressed);
}

/// Logo pequeño configurado en la base de datos (o assets/images/logo.png).
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: FundacionInfo.cambios,
        builder: (context, _, __) => SizedBox(
          width: 40,
          height: 40,
          child: ClipOval(
            child: FundacionImagen(
              ruta: FundacionInfo.logo.isEmpty
                  ? 'assets/images/logo.png'
                  : FundacionInfo.logo,
              fit: BoxFit.cover,
              icono: Icons.pets,
              tamanoIcono: 22,
            ),
          ),
        ),
      );
}
