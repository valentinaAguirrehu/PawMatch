import 'dart:ui';
import 'package:flutter/material.dart';

/// Tarjeta de logro con animación count-up progresiva (inicia visualmente en 0 y sube progresivamente),
/// diseño delicado glassmorphic semi-transparente en tonos pastel, ícono y número juntos y centrados.
/// Totalmente adaptable a 2 columnas en móvil y 4 columnas en escritorio.
class StatLogro extends StatefulWidget {
  final IconData icono;
  final int valorNumero;
  final String etiqueta;
  final bool cargando;
  final bool error;
  final bool animar;

  const StatLogro({
    super.key,
    required this.icono,
    required this.valorNumero,
    required this.etiqueta,
    this.cargando = false,
    this.error = false,
    this.animar = false,
  });

  @override
  State<StatLogro> createState() => _StatLogroState();
}

class _StatLogroState extends State<StatLogro> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  late final Animation<double> _curva = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  bool _haIniciadoAnimacion = false;

  @override
  void initState() {
    super.initState();
    _evaluarInicioAnimacion();
  }

  @override
  void didUpdateWidget(StatLogro oldWidget) {
    super.didUpdateWidget(oldWidget);
    _evaluarInicioAnimacion();
  }

  void _evaluarInicioAnimacion() {
    if (_haIniciadoAnimacion) return;
    if (widget.animar && !widget.cargando && !widget.error) {
      _haIniciadoAnimacion = true;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compacto = w < 185;
        final muyCompacto = w < 145;

        final padH = muyCompacto ? 8.0 : (compacto ? 12.0 : 16.0);
        final padV = muyCompacto ? 12.0 : (compacto ? 16.0 : 22.0);
        final radioBorde = compacto ? 20.0 : 24.0;
        final tamCirculo = muyCompacto ? 34.0 : (compacto ? 40.0 : 48.0);
        final tamIcono = muyCompacto ? 18.0 : (compacto ? 21.0 : 25.0);
        final tamNumero = muyCompacto ? 26.0 : (compacto ? 32.0 : 42.0);
        final tamEtiqueta = muyCompacto ? 11.2 : (compacto ? 12.2 : 13.5);

        return ClipRRect(
          borderRadius: BorderRadius.circular(radioBorde),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(radioBorde),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF085AF).withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: tamCirculo,
                        height: tamCirculo,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.35),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            widget.icono,
                            color: Colors.white,
                            size: tamIcono,
                          ),
                        ),
                      ),
                      SizedBox(width: muyCompacto ? 8 : (compacto ? 10 : 14)),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _construirNumero(
                            sinAnimaciones: sinAnimaciones,
                            tamNumero: tamNumero,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compacto ? 8 : 12),
                  Text(
                    widget.etiqueta,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: tamEtiqueta,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _construirNumero({
    required bool sinAnimaciones,
    required double tamNumero,
  }) {
    if (widget.cargando) {
      return SizedBox(
        width: tamNumero * 0.65,
        height: tamNumero * 0.65,
        child: const CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
        ),
      );
    }
    if (widget.error) {
      return Text(
        '–',
        style: TextStyle(
          color: Colors.white,
          fontSize: tamNumero * 0.9,
          fontWeight: FontWeight.w900,
        ),
      );
    }
    if (sinAnimaciones) {
      return Text(
        '${widget.valorNumero}',
        style: TextStyle(
          color: Colors.white,
          fontSize: tamNumero,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _curva,
      builder: (context, _) {
        final int valorMostrado;
        if (!_haIniciadoAnimacion) {
          valorMostrado = 0;
        } else if (_controller.isCompleted) {
          valorMostrado = widget.valorNumero;
        } else {
          valorMostrado = (_curva.value * widget.valorNumero).round();
        }

        return Text(
          '$valorMostrado',
          style: TextStyle(
            color: Colors.white,
            fontSize: tamNumero,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            shadows: const [
              Shadow(
                color: Color(0x30000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        );
      },
    );
  }
}
