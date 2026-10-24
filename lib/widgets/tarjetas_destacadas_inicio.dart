import 'package:flutter/material.dart';
import 'package:paw_match/services/pets_service.dart';

/// Sección destacada con dos tarjetas limpias (sin fondo de foto),
/// colocadas SIEMPRE de lado y lado en modo celular, con bordes de color vibrante (Verde y Rosado).
class TarjetasDestacadasInicio extends StatelessWidget {
  final VoidCallback? onAdopta;
  final VoidCallback? onApadrina;

  const TarjetasDestacadasInicio({
    super.key,
    this.onAdopta,
    this.onApadrina,
  });

  String _tituloAdopcion(int conteo) {
    if (conteo == 1) {
      return '“Hay 1 peludito esperando un hogar”';
    }
    return '“Hay $conteo peluditos esperando un hogar”';
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final esMovilMuyPequeno = ancho < 360;
    final esMovilPequeno = ancho < 430;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: esMovilMuyPequeno ? 8 : (esMovilPequeno ? 12 : 20),
        vertical: esMovilPequeno ? 14 : 20,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cuadro 1: Adopción (Borde Verde Lima) con conteo dinámico desde la BD
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: PetsService.peluditosEsperando,
                builder: (context, conteo, _) {
                  return _TarjetaDestacadaLimpia(
                    colorTema: const Color(0xFF8EB827),
                    colorTextoDestacado: const Color(0xFF658A14),
                    titulo: _tituloAdopcion(conteo),
                    textoMayusculas: 'CONVIÉRTETE EN HOGAR, ',
                    textoNormal:
                        'y permíteles volver a saber qué se siente tener un hogar.',
                    botonTexto: 'Adoptar',
                    iconoBoton: Icons.favorite_rounded,
                    onTap: onAdopta,
                  );
                },
              ),
            ),

            SizedBox(width: esMovilMuyPequeno ? 8 : (esMovilPequeno ? 10 : 16)),

            // Cuadro 2: Apadrinamiento (Borde Rosado Fucsia)
            Expanded(
              child: _TarjetaDestacadaLimpia(
                colorTema: const Color(0xFFED4F9D),
                colorTextoDestacado: const Color(0xFFD61879),
                titulo: 'Ayúdanos a salvar más vidas',
                textoMayusculas: 'AL RECIBIR O APADRINAR, ',
                textoNormal:
                    'le permites a otro de la calle entrar al refugio.',
                botonTexto: 'Apadrinar',
                iconoBoton: Icons.volunteer_activism_rounded,
                onTap: onApadrina,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaDestacadaLimpia extends StatelessWidget {
  final Color colorTema;
  final Color colorTextoDestacado;
  final String titulo;
  final String textoMayusculas;
  final String textoNormal;
  final String botonTexto;
  final IconData iconoBoton;
  final VoidCallback? onTap;

  const _TarjetaDestacadaLimpia({
    required this.colorTema,
    required this.colorTextoDestacado,
    required this.titulo,
    required this.textoMayusculas,
    required this.textoNormal,
    required this.botonTexto,
    required this.iconoBoton,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final esMovilMuyPequeno = ancho < 360;
    final esMovilPequeno = ancho < 430;
    final esPantallaMedia = ancho >= 650;

    final tamanoTitulo = esMovilMuyPequeno
        ? 12.0
        : (esMovilPequeno
            ? 13.5
            : (esPantallaMedia ? 18.5 : 15.5));

    final tamanoTexto = esMovilMuyPequeno
        ? 9.0
        : (esMovilPequeno
            ? 10.2
            : (esPantallaMedia ? 12.5 : 11.2));

    final padH = esMovilMuyPequeno ? 8.0 : (esMovilPequeno ? 10.0 : 16.0);
    final padV = esMovilMuyPequeno ? 12.0 : (esMovilPequeno ? 14.0 : 18.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: colorTema.withValues(alpha: 0.15),
        highlightColor: colorTema.withValues(alpha: 0.08),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorTema,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: colorTema.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF242824),
                      fontSize: tamanoTitulo,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: esMovilPequeno ? 6 : 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        color: const Color(0xFF4A4E4A),
                        fontSize: tamanoTexto,
                        height: 1.35,
                      ),
                      children: [
                        TextSpan(
                          text: textoMayusculas,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: colorTextoDestacado,
                            letterSpacing: 0.3,
                          ),
                        ),
                        TextSpan(
                          text: textoNormal,
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: esMovilPequeno ? 8 : 12,
                  vertical: esMovilPequeno ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: colorTema,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorTema.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iconoBoton,
                      size: esMovilPequeno ? 12 : 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      botonTexto,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: esMovilPequeno ? 10.0 : 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
