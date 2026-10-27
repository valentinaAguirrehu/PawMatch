import 'dart:ui';
import 'package:flutter/material.dart';

/// Tarjeta de logro con animación count-up progresiva (inicia visualmente en 0 y sube progresivamente),
/// diseño delicado glassmorphic semi-transparente en tonos pastel, ícono y número juntos y centrados.
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
    // Respeta la preferencia de accesibilidad del usuario (prefers-reduced-motion)
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(24),
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
              // Fila centrada: Ícono + Número grande uno al lado del otro
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ícono en insignia circular translúcida
                  Container(
                    width: 48,
                    height: 48,
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
                        size: 25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Número animado ascendente (inicia visualmente en 0 y sube progresivamente)
                  if (widget.cargando)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  else if (widget.error)
                    const Text(
                      '–',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  else if (sinAnimaciones)
                    Text(
                      '${widget.valorNumero}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    )
                  else
                    AnimatedBuilder(
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Color(0x30000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Etiqueta descriptiva centrada
              Text(
                widget.etiqueta,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
