import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';

/// Tarjeta informativa de una forma de ayudar a la Fundación.
/// Se adapta automáticamente para mostrarse en 2 columnas incluso en vista móvil.
class TarjetaAyuda extends StatelessWidget {
  final IconData icono;
  final String titulo, texto;
  const TarjetaAyuda({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compacto = w < 215;
        final muyCompacto = w < 165;

        final pad = muyCompacto ? 12.0 : (compacto ? 15.0 : 20.0);
        final radioBorde = compacto ? 22.0 : 28.0;
        final radioAvatar = muyCompacto ? 16.0 : (compacto ? 18.0 : 24.0);
        final tamIcono = muyCompacto ? 16.0 : (compacto ? 18.0 : 24.0);
        final tamTitulo = muyCompacto ? 11.5 : (compacto ? 12.5 : 15.0);
        final tamTexto = muyCompacto ? 11.5 : (compacto ? 12.5 : 14.0);

        return Container(
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radioBorde),
            border: Border.all(color: AppColors.bordeRosa),
            boxShadow: [
              BoxShadow(
                color: AppColors.rosa.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: radioAvatar,
                    backgroundColor: AppColors.rosaClaro,
                    child: Icon(icono, color: AppColors.rosa, size: tamIcono),
                  ),
                  SizedBox(width: muyCompacto ? 8 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titulo.toUpperCase(),
                          softWrap: true,
                          style: t.titleMedium?.copyWith(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: tamTitulo,
                            letterSpacing: 0.15,
                            color: AppColors.texto,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: muyCompacto ? 24 : 34,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.rosa,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: muyCompacto ? 9 : 12),
              Text(
                texto,
                style: t.bodyMedium?.copyWith(
                  fontSize: tamTexto,
                  height: compacto ? 1.4 : 1.5,
                  color: AppColors.texto,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
