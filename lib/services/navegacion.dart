import 'package:flutter/material.dart';

/// Cambia la pantalla de inicio sin destruir la ruta raíz del [Navigator].
///
/// `pushAndRemoveUntil(..., (_) => false)` desmonta el Overlay mientras un
/// tooltip todavía depende de él y Flutter pinta la pantalla roja.
class Navegacion {
  Navegacion._();

  static void Function(Widget pagina)? mostrar;

  static void ir(BuildContext context, Widget pagina) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final tecladoAbierto = MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0;
    FocusManager.instance.primaryFocus?.unfocus();

    // El teclado cambia el MediaQuery durante varios frames. Si quitamos la
    // ruta de login mientras eso pasa, un campo sigue dependiendo de un
    // InheritedWidget que ya no es su ancestro y aparece la pantalla roja.
    void entrar() {
      if (!navigator.mounted) return;
      if (navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!navigator.mounted) return;
        mostrar?.call(pagina);
      });
    }

    void esperarCierre(int restantes) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!navigator.mounted) return;
        final abajo = MediaQuery.maybeViewInsetsOf(navigator.context)?.bottom ?? 0;
        if (abajo > 0 && restantes > 0) {
          esperarCierre(restantes - 1);
          return;
        }
        entrar();
      });
    }

    if (tecladoAbierto > 0) {
      esperarCierre(45);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => entrar());
    }
  }
}
