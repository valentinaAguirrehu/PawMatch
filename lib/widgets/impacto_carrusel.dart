import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/widgets/punto_inicio.dart';

/// Carrusel de tarjetas con el impacto de adoptar o apadrinar.
class ImpactoCarrusel extends StatefulWidget {
  final String titulo;
  final List<PuntoInicio> items;

  const ImpactoCarrusel({
    super.key,
    required this.titulo,
    required this.items,
  });

  @override
  State<ImpactoCarrusel> createState() => _ImpactoCarruselState();
}

class _ImpactoCarruselState extends State<ImpactoCarrusel> {
  final _controller = PageController(viewportFraction: 0.86);
  int _pagina = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.rosaSuave,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: AppColors.texto,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 262,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemBuilder: (context, i) {
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      double page = _pagina.toDouble();
                      if (_controller.hasClients &&
                          _controller.position.haveDimensions) {
                        page = _controller.page ?? page;
                      }
                      final escala = 1 -
                          (math.min(1.0, (page - i).abs()) * 0.07);
                      return Transform.scale(scale: escala, child: child);
                    },
                    child: _TarjetaImpacto(punto: widget.items[i]),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _pagina ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          i == _pagina ? AppColors.rosa : AppColors.bordeRosa,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaImpacto extends StatelessWidget {
  final PuntoInicio punto;

  const _TarjetaImpacto({required this.punto});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.rosa,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(punto.icono, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            punto.titulo,
            style: const TextStyle(
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: AppColors.texto,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              punto.texto,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.texto.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
