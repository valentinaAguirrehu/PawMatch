import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/layout.dart';

/// Barra superior fija de la landing: logo a la izquierda y los botones
/// "Iniciar sesión" y "Registrarse" a la derecha (se compacta en celular).
class LandingBarra extends StatelessWidget {
  final VoidCallback onIniciarSesion, onRegistrarse;
  const LandingBarra({super.key, required this.onIniciarSesion, required this.onRegistrarse});

  @override
  Widget build(BuildContext context) {
    final angosto = MediaQuery.sizeOf(context).width < 480;
    return Material(
      color: Colors.white,
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: angosto ? 12 : 24, vertical: 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Layout.anchoMaximo),
              child: Row(children: [
                const _Logo(),
                if (!angosto) ...[
                  const SizedBox(width: 10),
                  Text('Paw Match',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppColors.rosa, fontWeight: FontWeight.w800)),
                ],
                const Spacer(),
                TextButton(onPressed: onIniciarSesion, child: const Text('Iniciar sesión')),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: onRegistrarse,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Registrarse'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo pequeño (assets/images/logo.png); si no existe, una huella.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 40,
        height: 40,
        child: ClipOval(
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: AppColors.rosaClaro,
              child: Icon(Icons.pets, color: AppColors.rosa, size: 22),
            ),
          ),
        ),
      );
}
