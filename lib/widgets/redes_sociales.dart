import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';

/// Botones de Facebook, Instagram y WhatsApp de la Fundación.
/// `conTexto`: botones con nombre; si no, solo círculos con ícono.
/// `sobreRosa`: colores invertidos para fondos rosados.
class RedesSociales extends StatelessWidget {
  final bool conTexto, sobreRosa;
  const RedesSociales({super.key, this.conTexto = false, this.sobreRosa = false});

  @override
  Widget build(BuildContext context) {
    final fondo = sobreRosa ? Colors.white : AppColors.rosa;
    final letra = sobreRosa ? AppColors.rosa : Colors.white;

    Widget boton(IconData icono, String nombre, String url) {
      if (conTexto) {
        return FilledButton.icon(
          onPressed: () => abrirEnlace(context, url, nombre: nombre),
          icon: Icon(icono, size: 20),
          label: Text(nombre),
          style: FilledButton.styleFrom(
            backgroundColor: fondo,
            foregroundColor: letra,
            minimumSize: const Size(0, 46),
            shape: const StadiumBorder(),
          ),
        );
      }
      return Tooltip(
        message: nombre,
        child: Material(
          color: fondo,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => abrirEnlace(context, url, nombre: nombre),
            child: Padding(padding: const EdgeInsets.all(11), child: Icon(icono, color: letra, size: 22)),
          ),
        ),
      );
    }

    return Wrap(spacing: 10, runSpacing: 10, children: [
      boton(Icons.facebook, 'Facebook', FundacionInfo.facebookUrl),
      boton(Icons.camera_alt_outlined, 'Instagram', FundacionInfo.instagramUrl),
      boton(Icons.chat_bubble_outline, 'WhatsApp', FundacionInfo.whatsappUrl),
    ]);
  }
}
