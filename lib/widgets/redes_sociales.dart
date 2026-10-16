import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';

/// Botones de redes sociales y contacto de la Fundación.
/// Muestra dinámicamente solo las redes que tienen URL configurada.
class RedesSociales extends StatelessWidget {
  final bool conTexto, sobreRosa;
  const RedesSociales({super.key, this.conTexto = false, this.sobreRosa = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FundacionInfo.cambios,
      builder: (context, _, __) {
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
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(icono, color: letra, size: 22),
                ),
              ),
            ),
          );
        }

        final items = <Widget>[];

        final facebook = FundacionInfo.redes['facebook'] ?? '';
        if (facebook.isNotEmpty) {
          items.add(boton(Icons.facebook, 'Facebook', facebook));
        }

        final instagram = FundacionInfo.redes['instagram'] ?? '';
        if (instagram.isNotEmpty) {
          items.add(boton(Icons.camera_alt_outlined, 'Instagram', instagram));
        }

        final tiktok = FundacionInfo.redes['tiktok'] ?? '';
        if (tiktok.isNotEmpty) {
          items.add(boton(Icons.music_note_outlined, 'TikTok', tiktok));
        }

        final whatsapp = FundacionInfo.whatsappUrl;
        if (whatsapp.isNotEmpty) {
          items.add(boton(Icons.chat_bubble_outline, 'WhatsApp', whatsapp));
        }

        final correo = FundacionInfo.correo;
        if (correo.isNotEmpty) {
          items.add(boton(Icons.email_outlined, 'Correo', FundacionInfo.correoUrl));
        }

        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Wrap(spacing: 10, runSpacing: 10, children: items);
      },
    );
  }
}
