import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/core/enlaces.dart';
import 'package:paw_match/core/fundacion_info.dart';

/// Botones horizontales, compactos y modernos de redes sociales y contacto de la Fundación.
/// Muestra dinámicamente solo las redes que tienen URL configurada.
class RedesSociales extends StatelessWidget {
  final bool conTexto, sobreRosa;
  const RedesSociales({
    super.key,
    this.conTexto = false,
    this.sobreRosa = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FundacionInfo.cambios,
      builder: (context, _, _) {
        final fondo = sobreRosa ? Colors.white : AppColors.rosa;
        final letra = sobreRosa ? AppColors.rosa : Colors.white;

        final datos = <(FaIconData, String, String)>[];

        final facebook = FundacionInfo.redes['facebook'] ?? '';
        if (facebook.isNotEmpty) {
          datos.add((FontAwesomeIcons.facebookF, 'Facebook', facebook));
        }

        final instagram = FundacionInfo.redes['instagram'] ?? '';
        if (instagram.isNotEmpty) {
          datos.add((FontAwesomeIcons.instagram, 'Instagram', instagram));
        }

        final whatsapp = FundacionInfo.whatsappUrl;
        if (whatsapp.isNotEmpty) {
          datos.add((FontAwesomeIcons.whatsapp, 'WhatsApp', whatsapp));
        }

        final tiktok = FundacionInfo.redes['tiktok'] ?? '';
        if (tiktok.isNotEmpty) {
          datos.add((FontAwesomeIcons.tiktok, 'TikTok', tiktok));
        }

        final correo = FundacionInfo.correo;
        if (correo.isNotEmpty) {
          datos.add((FontAwesomeIcons.envelope, 'Correo', FundacionInfo.correoUrl));
        }

        if (datos.isEmpty) {
          return const SizedBox.shrink();
        }

        if (!conTexto) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final d in datos)
                Tooltip(
                  message: d.$2,
                  child: Material(
                    color: fondo,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => abrirEnlace(context, d.$3, nombre: d.$2),
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: FaIcon(d.$1, color: letra, size: 19),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final muyCompacto = maxW < 210;
            final sep = muyCompacto ? 6.0 : 8.0;
            final int porFila = maxW >= 290
                ? datos.length.clamp(1, 3)
                : (maxW >= 205 ? 2 : 1);
            final double anchoBoton = porFila > 1
                ? ((maxW - sep * (porFila - 1)) / porFila).clamp(80.0, 190.0)
                : maxW;

            return Wrap(
              spacing: sep,
              runSpacing: sep,
              children: [
                for (final d in datos)
                  SizedBox(
                    width: anchoBoton,
                    height: muyCompacto ? 36 : 42,
                    child: FilledButton(
                      onPressed: () => abrirEnlace(context, d.$3, nombre: d.$2),
                      style: FilledButton.styleFrom(
                        backgroundColor: fondo,
                        foregroundColor: letra,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: muyCompacto ? 8 : 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(muyCompacto ? 11 : 14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(d.$1, size: muyCompacto ? 13.5 : 15, color: letra),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              d.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: letra,
                                fontWeight: FontWeight.w700,
                                fontSize: muyCompacto ? 11.5 : 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
