import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:paw_match/core/app_colors.dart';
import 'package:paw_match/models/pet.dart';
import 'package:paw_match/widgets/perrito_landing_card.dart';

/// Carrusel adaptable de perritos para la pantalla de bienvenida.
/// En celulares Android muestra exactamente 2 tarjetas lado a lado por página
/// con flechas elegantes (← / →) para avanzar y retroceder sin cubrir el contenido.
/// En computadores distribuye los perritos horizontalmente en cuadrícula amplia.
class PerritosCarrusel extends StatefulWidget {
  final List<Pet> perros;
  final void Function(Pet pet) onPedirCuenta;

  const PerritosCarrusel({
    super.key,
    required this.perros,
    required this.onPedirCuenta,
  });

  @override
  State<PerritosCarrusel> createState() => _PerritosCarruselState();
}

class _PerritosCarruselState extends State<PerritosCarrusel> {
  late final PageController _pageController = PageController();
  int _paginaActual = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _irAPagina(int nuevaPagina) {
    if (nuevaPagina < 0) return;
    _pageController.animateToPage(
      nuevaPagina,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.perros.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoDisponible = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final esEscritorio = anchoDisponible >= 820;
        final esTablet = anchoDisponible >= 560 && !esEscritorio;
        final double sep = esEscritorio ? 14.0 : (esTablet ? 12.0 : 10.0);

        final int itemsPorPagina = esEscritorio ? 4 : (esTablet ? 3 : 2);
        final int totalPaginas = (widget.perros.length / itemsPorPagina).ceil();
        final double alturaCarrusel = esEscritorio
            ? 280.0
            : (esTablet ? 260.0 : 235.0);

        final int paginaSegura = _paginaActual.clamp(0, math.max(0, totalPaginas - 1));

        // Si todos caben en una sola fila (ej. PC con <= 4 perritos), fila directa
        if (totalPaginas <= 1) {
          return SizedBox(
            height: alturaCarrusel,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < itemsPorPagina; i++) ...[
                  if (i > 0) SizedBox(width: sep),
                  Expanded(
                    child: i < widget.perros.length
                        ? PerritoLandingCard(
                            pet: widget.perros[i],
                            paraAdopcion: true,
                            onTap: () => widget.onPedirCuenta(widget.perros[i]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: alturaCarrusel,
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: totalPaginas,
                onPageChanged: (index) {
                  setState(() {
                    _paginaActual = index;
                  });
                },
                itemBuilder: (context, paginaIndex) {
                  final inicio = paginaIndex * itemsPorPagina;
                  final fin = math.min(
                    inicio + itemsPorPagina,
                    widget.perros.length,
                  );
                  final perrosPagina = widget.perros.sublist(inicio, fin);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < itemsPorPagina; i++) ...[
                          if (i > 0) SizedBox(width: sep),
                          Expanded(
                            child: i < perrosPagina.length
                                ? PerritoLandingCard(
                                    pet: perrosPagina[i],
                                    paraAdopcion: true,
                                    onTap: () =>
                                        widget.onPedirCuenta(perrosPagina[i]),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Barra de navegación con flechas rosa pastel e indicadores
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BotonFlechaCarrusel(
                  icono: Icons.arrow_back_ios_new_rounded,
                  habilitado: paginaSegura > 0,
                  onTap: paginaSegura > 0
                      ? () => _irAPagina(paginaSegura - 1)
                      : null,
                  tooltip: 'Perritos anteriores',
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(totalPaginas, (index) {
                      final bool esActivo = index == paginaSegura;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        width: esActivo ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: esActivo
                              ? AppColors.rosa
                              : AppColors.bordeRosa.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                _BotonFlechaCarrusel(
                  icono: Icons.arrow_forward_ios_rounded,
                  habilitado: paginaSegura < totalPaginas - 1,
                  onTap: paginaSegura < totalPaginas - 1
                      ? () => _irAPagina(paginaSegura + 1)
                      : null,
                  tooltip: 'Siguientes perritos',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Botón circular de flecha con diseño rosa pastel, estados activo/desactivado y tacto cómodo.
class _BotonFlechaCarrusel extends StatelessWidget {
  final IconData icono;
  final bool habilitado;
  final VoidCallback? onTap;
  final String tooltip;

  const _BotonFlechaCarrusel({
    required this.icono,
    required this.habilitado,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: habilitado ? 1.0 : 0.35,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: habilitado
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFD8BB9),
                          AppColors.rosa,
                        ],
                      )
                    : null,
                color: habilitado ? null : AppColors.rosaSuave,
                shape: BoxShape.circle,
                border: Border.all(
                  color: habilitado ? Colors.white.withValues(alpha: 0.7) : AppColors.bordeRosa,
                  width: 1.2,
                ),
                boxShadow: habilitado
                    ? [
                        BoxShadow(
                          color: AppColors.rosa.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  icono,
                  size: 18,
                  color: habilitado ? Colors.white : AppColors.bordeRosa,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
