import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Indicador de espera que se cierra en el mismo navegador donde se abrió.
///
/// La app tiene un navegador interno. `showDialog` usa el de la raíz y
/// `Navigator.pop(context)` cierra otra ruta, así que la pantalla se queda oscura.
class DialogoCarga {
  DialogoCarga._();

  static Future<T> mientras<T>(BuildContext context, Future<T> Function() tarea) async {
    final navegador = Navigator.of(context, rootNavigator: true);
    var abierto = true;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.rosa),
      ),
    ).whenComplete(() => abierto = false);
    await Future<void>.delayed(Duration.zero);
    try {
      return await tarea();
    } finally {
      if (abierto) {
        abierto = false;
        navegador.pop();
      }
    }
  }
}
