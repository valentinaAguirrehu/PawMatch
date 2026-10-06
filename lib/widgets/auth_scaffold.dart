import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Fondo rosado de las pantallas de acceso: contenido centrado, ancho máximo
/// cómodo en web y botón de volver blanco cuando hay pantalla anterior.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  const AuthScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.rosa,
        body: SafeArea(
          child: Stack(children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 56, 28, 28),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: child),
              ),
            ),
            if (Navigator.canPop(context))
              const Positioned(left: 4, top: 4, child: BackButton(color: Colors.white)),
          ]),
        ),
      );
}
